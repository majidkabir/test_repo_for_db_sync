SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PrintshipLabel_jaspal_RDT                           */
/* Creation Date: 10-Aug-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Mingle                                                   */
/*                                                                      */
/* Purpose:  WMS-20460                                                  */
/*        :                                                             */
/* Called By: r_dw_print_shiplabel_jaspal_rdt                           */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2022-08-10   MINGLE    1.0 DevOps Combine Script(Created)            */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintshipLabel_jaspal_RDT] (  
   @c_Externorderkey NVARCHAR(21) )   
 
AS   
BEGIN  
   SET NOCOUNT ON  
  -- SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  

   SELECT DISTINCT OH.ExternOrderKey,
                   OH.C_contact1,
                   OH.C_Phone1,
                   CONCAT(ISNULL(OH.C_Address1,''),ISNULL(OH.C_Address2,''),ISNULL(OH.C_Address3,''),ISNULL(OH.C_Address4,''),
				   '',ISNULL(OH.C_City,''),'',ISNULL(OH.C_Country,''),'-',ISNULL(OH.C_Zip,'')) AS OHAddress,
				   CASE WHEN OH.PmtTerm = 'CC' THEN 'PAID' ELSE 'COD' END,
				   CASE WHEN OH.PmtTerm = 'CC' THEN 'VND 0' ELSE 'VND ' + REPLACE(FORMAT(CAST(OH.InvoiceAmount AS INT), '#,#'),',','.') END,
				  -- case when LEN(CAST(OH.InvoiceAmount AS INT))/3 = 0 THEN 'b'
				  --      WHEN LEN(CAST(OH.InvoiceAmount AS INT))/3 = 2 THEN STUFF(STUFF(CAST(OH.InvoiceAmount AS INT),4,0,'.'),8,0,'.')
						--ELSE '' END AS test,
				  -- case when LEN(CAST(OH.InvoiceAmount AS INT))/3 = 2 THEN STUFF(STUFF(CAST(OH.InvoiceAmount AS INT),4,0,'.'),8,0,'.') else 'error' END AS c,
				  -- case when convert(INT,LEN(OH.InvoiceAmount)/3) = 2 THEN STUFF(STUFF(OH.InvoiceAmount,4,0,'.'),8,0,'.') else 'error' END,
				  -- LEN(CAST(OH.InvoiceAmount AS INT))/3 AS correct,
				   --EXEC isp_PrintshipLabel_jaspal_RDT 'VNLYNOVN37204'
				  -- CASE WHEN LEN(CAST(OH.InvoiceAmount AS INT))/3 = 0 
				  --      THEN STR(OH.InvoiceAmount,3)
						--WHEN LEN(CAST(OH.InvoiceAmount AS INT))/3 = 1 
				  --      THEN STUFF(CAST(OH.InvoiceAmount AS INT),4,0,'.')
						--WHEN LEN(CAST(OH.InvoiceAmount AS INT))/3 = 2 
				  --      THEN STUFF(STUFF(CAST(OH.InvoiceAmount AS INT),-4,0,'.'),-8,0,'.')
				  --      WHEN LEN(CAST(OH.InvoiceAmount AS INT))/3 = 3
						--THEN STUFF(STUFF(STUFF(OH.InvoiceAmount,4,0,'.'),8,0,'.'),12,0,'.')
						--WHEN LEN(CAST(OH.InvoiceAmount AS INT))/3 = 4
					 --   THEN STUFF(STUFF(STUFF(STUFF(OH.InvoiceAmount,4,0,'.'),8,0,'.'),12,0,'.'),16,0,'.')
						--WHEN LEN(CAST(OH.InvoiceAmount AS INT))/3 = 5
						--THEN STUFF(STUFF(STUFF(STUFF(STUFF(OH.InvoiceAmount,4,0,'.'),8,0,'.'),12,0,'.'),16,0,'.'),20,0,'.') 
						--ELSE '' END,
				   DATEADD(DAY,3,OH.OrderDate) AS OHOrderDate,
				   ISNULL(CL.Notes2,''),
				   ISNULL(CL.Short,''),
				   ISNULL(CL.Notes,''),
				   ISNULL(CL.UDF01,'') + ISNULL(CL.UDF02,'') + ISNULL(CL.UDF03,'') + ISNULL(CL.UDF04,'') + ISNULL(CL.UDF05,'')
   FROM ORDERS OH WITH (NOLOCK)
   LEFT JOIN CODELKUP CL(NOLOCK) ON CL.LISTNAME = 'NJVSHPLBL' AND CL.Storerkey = OH.StorerKey AND CL.CODE = '1'
   WHERE OH.ExternOrderKey = @c_Externorderkey
  

END -- procedure

GO