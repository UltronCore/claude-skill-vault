# Skill Memory: Form Generator with React Hook Form & Zod

## Purpose
Generates complete, production-ready React form components using React Hook Form with zodResolver, Zod validation schemas, and shadcn/ui form controls. Covers all field types (text, select, checkbox, date, file, combobox, etc.), server actions with server-side validation, accessibility via FormLabel/FormMessage/FormDescription, and patterns like useFieldArray, file upload with preview, and conditional fields.

## Category notes
Belongs in ui-ux because it directly produces user interface components and defines the interaction pattern for all data entry in React applications. The output is a visible, interactive UI element.

## Relationships
- Pairs with tailwind-shadcn-ui-setup as a prerequisite (shadcn/ui form components must be installed)
- Pairs with markdown-editor-integrator when textarea fields need rich text capabilities
- Outputs server actions that relate to server-actions-vs-api-optimizer concerns

## Maintenance notes
Relies on @hookform/resolvers, react-hook-form, zod, and shadcn/ui form components. If shadcn/ui updates its Form component API, update the FormField render pattern examples.
