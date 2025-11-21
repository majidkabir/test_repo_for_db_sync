SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_UPLOADORDERHEADER]   
AS   
SELECT [Orderkey]  
, [Storerkey]  
, [externorderkey]  
, [OrderGroup]  
, [Orderdate]  
, [Deliverydate]  
, [Type]  
, [ConsigneeKey]  
, [Priority]  
, [Salesman]  
, [c_contact1]  
, [c_contact2]  
, [c_company]  
, [c_address1]  
, [c_address2]  
, [c_address3]  
, [c_address4]  
, [c_city]  
, [c_state]  
, [c_zip]  
, [buyerpo]  
, [notes]  
, [invoiceno]  
, [notes2]  
, [pmtterm]  
, [invoiceamount]  
, [ROUTE]  
, [Mode]  
, [status]  
, [remarks]  
, [AddDate]  
FROM [UPLOADORDERHEADER] (NOLOCK)   
GO