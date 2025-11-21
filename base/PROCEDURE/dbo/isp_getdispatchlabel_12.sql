SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_GetDispatchLabel_12                                   */              
/* Creation Date: 04-Sep-2019                                                 */              
/* Copyright: LFL                                                             */              
/* Written by:                                                                */              
/*                                                                            */              
/* Purpose: WMS-10475-TH-JDSport customize new Dispatch Label for ecom Orders */
/*          Copy from r_dw_dispatch_label_11                                  */
/*                                                                            */              
/*                                                                            */              
/* Called By: r_dw_dispatch_label_12                                          */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */ 
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_GetDispatchLabel_12]             
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
           @c_Storerkey       NVARCHAR(15) = ''
   
   IF @c_ORDERNumber = NULL SET @c_ORDERNumber = ''
   IF @c_CurrentPage = NULL OR @c_CurrentPage = '' SET @c_CurrentPage = '0'

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
      FROM MBOLDETAIL MD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = MD.ORDERKEY
      WHERE MD.MBOLKEY = @c_MBOLNumber
   END

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT @c_CarrierKey = CL.Code
      FROM MBOL (NOLOCK)
      JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'JDSCarrier' AND CL.CODE = MBOL.CARRIERKEY AND CL.Storerkey = @c_Storerkey
      WHERE MBOL.MBOLKEY = @c_MBOLNumber

      IF(ISNULL(@c_CarrierKey,'') = '')
      BEGIN
         SET @c_CarrierKey = ''
      END
   END

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT MBOLDETAIL.MbolKey,   
             MBOLDETAIL.OrderKey,
             ORDERS_EXTERNORDERKEY = LEFT(LTRIM(RTRIM(ORDERS.EXTERNORDERKEY)),15),   
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
             ELSE CASE WHEN ISNULL(ORDERS.Trackingno,'') <> ''
                  THEN LEFT(LTRIM(RTRIM(ISNULL(ORDERS.Trackingno,''))),15) + '-' + RIGHT('00000' + @c_CurrentPage, 3)
                  ELSE RIGHT('00000' + @c_CurrentPage, 3) END 
             END AS TrackingNo,
             CASE WHEN @c_CarrierKey = '' THEN ORDERS.Route ELSE '' END,
             @c_CarrierKey
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