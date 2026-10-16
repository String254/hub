//const baseUrl = 'http://127.0.0.1:8000/api';
const baseUrl = 'https://marketfella.com/public/api';

//Register, Login, Logout, Update User
const loginUrl = '$baseUrl/login';
const registerUrl = '$baseUrl/register';
const resetPasswordUrl = '$baseUrl/forgot-password';
const logoutUrl = '$baseUrl/logout';
const deleteUrl = '$baseUrl/delete';
const userUrl = '$baseUrl/user';

//Dashboard
const dashboard = '$baseUrl/dashboard';
const recentPayments = '$baseUrl/payments/recent';
const addProperty = '$baseUrl/properties';
const myProperty = '$baseUrl/properties';
const rates = '$baseUrl/rates';
const allRevenue = '$baseUrl/propertiesRevenue';
const unitDetails = '$baseUrl/units';
const dialog = '$baseUrl/dialogs';


//Property Page
const manageProperty = '$baseUrl/propertyDetails';
const managePayments = '$baseUrl/recentPropertyPayments';
const manageTenants = '$baseUrl/propertyTenants';
const manageRevenue = '$baseUrl/propertyRevenue';
const addTenant = '$baseUrl/tenants';
const addUnit = '$baseUrl/units';
const deleteTenant = '$baseUrl/remove';
const invoice = '$baseUrl/addInvoice';
const invoices = '$baseUrl/tenantInvoices';
const receipt = '$baseUrl/invoice'; //get invoice by id
const newReceipt = '$baseUrl/payments';
const showUnits = '$baseUrl/unit';
const allInvoices = '$baseUrl/allInvoices'; //all invoices
const bulkInvoice = '$baseUrl/bulk'; //generate all invoices

//Manage Page
const addMaintenance = '$baseUrl/maintenance';
const maintenanceIssues = '$baseUrl/maintenances';
const updateMaintenanceStatus = '$baseUrl/update';

//Documents Page
const myDocuments = '$baseUrl/documents';
const userDocuments = '$baseUrl/myDocuments';
const addDocument = '$baseUrl/documents/upload';
const deleteDocuments = '$baseUrl/documents';


//Notifications Page
const mpesaNotifications = '$baseUrl/notifications';
const maintenanceNotifications = '$baseUrl/maintenance';
const overdueNotifications = '$baseUrl/overdue';


//Uploads Page
const uploadInvoice = '$baseUrl/upload-invoice';
const uploadReceipt = '$baseUrl/upload-receipt';



//Chatbot
const chatbot = 'https://kejahub125.app.n8n.cloud/webhook/ai/property-manager';
const sessionToken = '$baseUrl/ai/session';


//N8N Webhooks
const overdueReminder = '$baseUrl/overdue';


///---------Errors---------////
const serverError = "Internet connection lost";
const unauthorized = "Unauthorized";
const somethingWentWrong = "Something went wrong, try again";
