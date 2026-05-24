---
name: android-development
description: Build native Android apps with Kotlin, Jetpack Compose, and modern Android architecture. Covers Compose UI, ViewModel, Room, Retrofit, Hilt DI, Coroutines, and Play Store deployment.
version: 1.0.0
tags: [android, kotlin, jetpack-compose, android-architecture, room, hilt, coroutines, mobile]
---

# Android Development

## Overview

This skill covers building production Android apps with modern Android development practices: Jetpack Compose for UI, ViewModel + StateFlow for state management, Room for local persistence, Retrofit for networking, Hilt for dependency injection, and Kotlin Coroutines for async operations. Targets developers building apps for Android 8.0+ (API 26+).

## When to Use

- Building a new Android app from scratch with modern stack
- Migrating from XML layouts and View system to Jetpack Compose
- Adding features to an existing Android app (Room, Retrofit, Hilt)
- Debugging Android performance or crash issues
- Preparing an app for Play Store submission

## Step-by-Step Workflow

### 1. Project Structure (Clean Architecture)
```
app/
├── src/main/
│   ├── java/com/example/app/
│   │   ├── data/
│   │   │   ├── local/         # Room database, DAOs
│   │   │   ├── remote/        # Retrofit API, DTOs
│   │   │   └── repository/    # Repository implementations
│   │   ├── domain/
│   │   │   ├── model/         # Domain models
│   │   │   ├── repository/    # Repository interfaces
│   │   │   └── usecase/       # Use cases
│   │   ├── presentation/
│   │   │   ├── ui/            # Composable screens
│   │   │   ├── viewmodel/     # ViewModels
│   │   │   └── theme/         # Compose theme
│   │   └── di/                # Hilt modules
│   └── AndroidManifest.xml
├── build.gradle.kts
└── proguard-rules.pro
```

### 2. Jetpack Compose UI
```kotlin
// presentation/ui/products/ProductsScreen.kt
package com.example.app.presentation.ui.products

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun ProductsScreen(
    onProductClick: (String) -> Unit,
    viewModel: ProductsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Products") })
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            when (val state = uiState) {
                is ProductsUiState.Loading -> CircularProgressIndicator()
                is ProductsUiState.Error -> ErrorMessage(
                    message = state.message,
                    onRetry = viewModel::loadProducts
                )
                is ProductsUiState.Success -> ProductList(
                    products = state.products,
                    onProductClick = onProductClick
                )
            }
        }
    }
}

@Composable
private fun ProductList(
    products: List<ProductUi>,
    onProductClick: (String) -> Unit,
) {
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(products, key = { it.id }) { product ->
            ProductCard(product = product, onClick = { onProductClick(product.id) })
        }
    }
}

@Composable
private fun ProductCard(product: ProductUi, onClick: () -> Unit) {
    ElevatedCard(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(16.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(product.name, style = MaterialTheme.typography.titleMedium)
                Text("$${product.price}", style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.primary)
            }
        }
    }
}
```

### 3. ViewModel with StateFlow
```kotlin
// presentation/viewmodel/ProductsViewModel.kt
@HiltViewModel
class ProductsViewModel @Inject constructor(
    private val getProductsUseCase: GetProductsUseCase,
) : ViewModel() {
    
    private val _uiState = MutableStateFlow<ProductsUiState>(ProductsUiState.Loading)
    val uiState: StateFlow<ProductsUiState> = _uiState.asStateFlow()
    
    init {
        loadProducts()
    }
    
    fun loadProducts() {
        viewModelScope.launch {
            _uiState.value = ProductsUiState.Loading
            getProductsUseCase()
                .onSuccess { products ->
                    _uiState.value = ProductsUiState.Success(
                        products = products.map { it.toUi() }
                    )
                }
                .onFailure { error ->
                    _uiState.value = ProductsUiState.Error(
                        message = error.message ?: "Unknown error"
                    )
                }
        }
    }
}

sealed interface ProductsUiState {
    data object Loading : ProductsUiState
    data class Success(val products: List<ProductUi>) : ProductsUiState
    data class Error(val message: String) : ProductsUiState
}
```

### 4. Room Database
```kotlin
// data/local/ProductDatabase.kt
@Entity(tableName = "products")
data class ProductEntity(
    @PrimaryKey val id: String,
    val name: String,
    val price: Double,
    val categoryId: String,
    val isFavorite: Boolean = false,
    val lastUpdated: Long = System.currentTimeMillis()
)

@Dao
interface ProductDao {
    @Query("SELECT * FROM products ORDER BY name ASC")
    fun getAllProducts(): Flow<List<ProductEntity>>
    
    @Query("SELECT * FROM products WHERE id = :id")
    suspend fun getProduct(id: String): ProductEntity?
    
    @Upsert
    suspend fun upsertProducts(products: List<ProductEntity>)
    
    @Query("UPDATE products SET isFavorite = :isFavorite WHERE id = :id")
    suspend fun toggleFavorite(id: String, isFavorite: Boolean)
    
    @Query("DELETE FROM products WHERE lastUpdated < :timestamp")
    suspend fun deleteOldProducts(timestamp: Long)
}

@Database(entities = [ProductEntity::class], version = 1, exportSchema = true)
abstract class AppDatabase : RoomDatabase() {
    abstract fun productDao(): ProductDao
}
```

### 5. Retrofit Networking
```kotlin
// data/remote/ProductApiService.kt
interface ProductApiService {
    @GET("products")
    suspend fun getProducts(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20,
        @Query("category") category: String? = null,
    ): ProductsResponse
    
    @GET("products/{id}")
    suspend fun getProduct(@Path("id") id: String): ProductDto
}

// Repository implementation
class ProductRepositoryImpl @Inject constructor(
    private val api: ProductApiService,
    private val dao: ProductDao,
) : ProductRepository {
    
    override fun getProducts(): Flow<Result<List<Product>>> = flow {
        // Emit cached data first (offline-first)
        val cached = dao.getAllProducts().first()
        if (cached.isNotEmpty()) {
            emit(Result.success(cached.map { it.toDomain() }))
        }
        
        // Fetch fresh data
        try {
            val response = api.getProducts()
            val entities = response.items.map { it.toEntity() }
            dao.upsertProducts(entities)
            emit(Result.success(entities.map { it.toDomain() }))
        } catch (e: Exception) {
            if (cached.isEmpty()) {
                emit(Result.failure(e))
            }
            // If we have cache, silently fail fresh fetch
        }
    }
}
```

### 6. Hilt Dependency Injection
```kotlin
// di/DatabaseModule.kt
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "app_database")
            .fallbackToDestructiveMigration()
            .build()
    
    @Provides
    fun provideProductDao(db: AppDatabase): ProductDao = db.productDao()
}

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    
    @Provides
    @Singleton
    fun provideRetrofit(): Retrofit = Retrofit.Builder()
        .baseUrl(BuildConfig.API_BASE_URL)
        .addConverterFactory(Json.asConverterFactory("application/json".toMediaType()))
        .client(OkHttpClient.Builder()
            .addInterceptor(AuthInterceptor())
            .connectTimeout(30, TimeUnit.SECONDS)
            .build())
        .build()
    
    @Provides
    fun provideProductApi(retrofit: Retrofit): ProductApiService =
        retrofit.create(ProductApiService::class.java)
}
```

## Key Commands Reference

```bash
# Build and run
./gradlew assembleDebug
./gradlew installDebug

# Run on connected device
adb devices
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Run tests
./gradlew test              # Unit tests
./gradlew connectedTest     # Instrumented tests

# Build release
./gradlew bundleRelease     # AAB for Play Store
./gradlew assembleRelease   # APK

# Code quality
./gradlew ktlintCheck
./gradlew detekt

# Analyze APK size
./gradlew :app:bundleRelease
bundletool build-apks --bundle=app-release.aab --output=app.apks
bundletool get-size total --apks=app.apks
```

## Common Patterns

### Pattern 1: Navigation with Compose Navigation
```kotlin
@Composable
fun AppNavGraph(navController: NavHostController) {
    NavHost(navController, startDestination = "products") {
        composable("products") {
            ProductsScreen(onProductClick = { id ->
                navController.navigate("product/$id")
            })
        }
        composable(
            route = "product/{productId}",
            arguments = listOf(navArgument("productId") { type = NavType.StringType })
        ) { backStackEntry ->
            ProductDetailScreen(
                productId = backStackEntry.arguments?.getString("productId") ?: "",
                onBack = navController::popBackStack
            )
        }
    }
}
```

### Pattern 2: DataStore for Preferences
```kotlin
val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

class UserPreferencesRepository @Inject constructor(
    private val dataStore: DataStore<Preferences>
) {
    private val DARK_MODE = booleanPreferencesKey("dark_mode")
    
    val darkMode: Flow<Boolean> = dataStore.data.map { it[DARK_MODE] ?: false }
    
    suspend fun setDarkMode(enabled: Boolean) {
        dataStore.edit { it[DARK_MODE] = enabled }
    }
}
```

### Pattern 3: Work Manager for Background Tasks
```kotlin
@HiltWorker
class SyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val repository: ProductRepository,
) : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result {
        return try {
            repository.syncFromServer()
            Result.success()
        } catch (e: Exception) {
            if (runAttemptCount < 3) Result.retry() else Result.failure()
        }
    }
}

// Schedule periodic sync
WorkManager.getInstance(context).enqueueUniquePeriodicWork(
    "product_sync",
    ExistingPeriodicWorkPolicy.KEEP,
    PeriodicWorkRequestBuilder<SyncWorker>(1, TimeUnit.HOURS)
        .setConstraints(Constraints(requiresNetworkType = NetworkType.CONNECTED))
        .build()
)
```

## Pitfalls to Avoid

1. **Blocking the main thread**: Any network, database, or file I/O on the main thread causes ANR (Application Not Responding). Use `viewModelScope.launch { }` for async work in ViewModels, and `Dispatchers.IO` for I/O operations in repositories. Room and Retrofit handle this automatically if you use `suspend` functions.

2. **Not handling configuration changes**: Screen rotation or multi-window destroys and recreates Activities. State must live in ViewModel, not Activity/Fragment. Don't store data in `onSaveInstanceState` for large objects — only for simple navigation state. StateFlow in ViewModel survives configuration changes.

3. **Memory leaks from Context**: Never store an Activity or View context in a singleton or ViewModel. Use `applicationContext` when you need a Context in long-lived components. Use `@ApplicationContext` in Hilt injections at the `SingletonComponent` level.

## Related Skills

- `android-reverse-engineering` — Analyzing compiled Android apps
- `flutter-development` — Cross-platform alternative for iOS+Android
- `kotlin-coroutines` — Advanced async patterns in Kotlin
- `app-store-connect` — Play Store deployment

## GitNexus Index

```json
{
  "skill": "android-development",
  "category": "ios-mobile",
  "triggers": ["android", "kotlin", "jetpack compose", "android app", "room database android", "hilt android", "viewmodel android"],
  "outputs": ["compose screen", "viewmodel", "room entity", "retrofit service", "hilt module"],
  "complexity": "high",
  "tools": ["android-studio", "kotlin", "gradle", "jetpack-compose", "room", "hilt", "retrofit"]
}
```
