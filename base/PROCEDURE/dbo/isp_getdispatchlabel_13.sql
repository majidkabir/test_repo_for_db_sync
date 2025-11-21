SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_GetDispatchLabel_13                                   */              
/* Creation Date: 12-MAY-2020                                                 */              
/* Copyright: LFL                                                             */              
/* Written by:                                                                */              
/*                                                                            */              
/* Purpose: WMS-13241-TH-JDSport CR new Dispatch Label for Ecom Orders        */
/*          Copy from r_dw_dispatch_label_11                                  */
/*                                                                            */              
/*                                                                            */              
/* Called By: r_dw_dispatch_label_13                                          */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */
/*28-OCT-2021   Mingle    1.1   WMS-17949 - Enlarge externordkey length(ML01) */ 
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_GetDispatchLabel_13]             
       (@c_MBOLNumber     NVARCHAR(10),
        @c_ORDERNumber    NVARCHAR(10) = '',
        @c_CurrentPage    NVARCHAR(10) = '',
        @c_TotalPage      NVARCHAR(10) = '')               
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @n_Continue        INT = 1,
           @c_CarrierKey      NVARCHAR(10) = '',
           @c_Storerkey       NVARCHAR(15) = '',
           @c_consigneekey    NVARCHAR(45) = ''
   
   IF @c_ORDERNumber = NULL SET @c_ORDERNumber = ''
   IF @c_CurrentPage = NULL OR @c_CurrentPage = '' SET @c_CurrentPage = '0'

   SET @c_consigneekey = ''

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
                   ,@c_consigneekey = ISNULL(OH.Consigneekey,'')
      FROM MBOLDETAIL MD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = MD.ORDERKEY
      WHERE MD.MBOLKEY = @c_MBOLNumber
   END

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT @c_CarrierKey = CL.Code
      FROM CODELKUP CL (NOLOCK) 
      WHERE CL.LISTNAME = 'JDSEcom' AND CL.CODE = @c_consigneekey AND CL.Storerkey = @c_Storerkey

      IF(ISNULL(@c_CarrierKey,'') = '')
      BEGIN
         SET @c_CarrierKey = ''
      END
   END

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT MBOLDETAIL.MbolKey,   
             MBOLDETAIL.OrderKey,
             ORDERS_EXTERNORDERKEY = LEFT(LTRIM(RTRIM(ORDERS.EXTERNORDERKEY)),25), --ML01  
             ORDERS.ConsigneeKey,   
             CASE WHEN @c_CarrierKey = '' THEN '' ELSE ORDERS.Shipperkey END,
             MBOL.vessel,   
             MBOLDETAIL.LoadKey,   
             ORDERS.DeliveryDate,   
             ORDERS.C_Company,
             ORDERS.C_Address1,
             ORDERS.C_Address2,
             ORDERS.C_Address3,
             ORDERS.C_Address4,
             City = (LTRIM(RTRIM(ISNULL(ORDERS.C_city,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_State,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_Zip,''))) ) ,
             currentpage = @c_CurrentPage,
             totalpage = MBOLDETAIL.totalcartons,
             CASE WHEN @c_CarrierKey = '' THEN ''
             ELSE LTRIM(RTRIM(ORDERS.EXTERNORDERKEY)) END AS ExtOrderkey,
             CASE WHEN @c_CarrierKey = '' THEN ORDERS.Route ELSE '' END AS route,
             @c_CarrierKey as carrierkey
      FROM MBOL (NOLOCK)
      JOIN MBOLDETAIL (NOLOCK) ON MBOLDETAIL.MBOLKEY = MBOL.MBOLKEY
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = MBOLDETAIL.ORDERKEY
      --LEFT JOIN PACKHEADER (NOLOCK) ON PACKHEADER.ORDERKEY = ORDERS.ORDERKEY
      --LEFT JOIN PACKDETAIL (NOLOCK) ON PACKDETAIL.PICKSLIPNO = PACKHEADER.PICKSLIPNO
      WHERE ( MBOLDETAIL.MBOLKey = @c_MBOLNumber ) AND
            ( MBOLDETAIL.OrderKey = CASE WHEN @c_ORDERNumber = '' THEN MBOLDETAIL.ORDERKEY ELSE @c_ORDERNumber END )   
   END
END

GO