SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                          
/* Store Procedure: isp_GetDispatchLabel_16                                   */                          
/* Creation Date: 13-Feb-2022                                                 */                          
/* Copyright: LFL                                                             */                          
/* Written by: mingle                                                         */                          
/*                                                                            */                          
/* Purpose: WMS-18918-TH-AROMA - CR Dispatch Label support Courier - Kerry    */                                      
/*                                                                            */                          
/* Called By: r_dw_dispatch_label_16                                          */                          
/*                                                                            */                          
/* PVCS Version: 1.0                                                          */                          
/*                                                                            */                          
/* Version: 7.0                                                               */                          
/*                                                                            */                          
/* Data Modifications:                                                        */                          
/*                                                                            */                          
/* Updates:                                                                   */                          
/* Date         Author    Ver.  Purposes                                      */  
/* 13-Feb-2022  Mingle    1.0   DeVops Combine Script                         */  
/* 28-Mar-2023  NJOW01		1.2   WMS-22083 Rebrand to Maersk                   */         
/******************************************************************************/                 
              
CREATE   PROC [dbo].[isp_GetDispatchLabel_16]                         
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
              
   --DECLARE @n_Continue        INT = 1,            
   --        @c_CarrierKey      NVARCHAR(10) = '',            
   --        @c_Storerkey       NVARCHAR(15) = ''            
               
   --IF @c_ORDERNumber = NULL SET @c_ORDERNumber = ''            
   --IF @c_CurrentPage = NULL OR @c_CurrentPage = '' SET @c_CurrentPage = '0'            
            
   --IF( @n_Continue = 1 OR @n_Continue = 2)            
   --BEGIN            
   --   SELECT TOP 1 @c_Storerkey = OH.Storerkey            
   --   FROM MBOLDETAIL MD (NOLOCK)            
   --   JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = MD.ORDERKEY            
   --   WHERE MD.MBOLKEY = @c_MBOLNumber            
   --END            
                  
            
   --IF( @n_Continue = 1 OR @n_Continue = 2)            
   --BEGIN            
      SELECT MBOLDETAIL.MbolKey,             
         MBOLDETAIL.OrderKey,          
         ORDERS_EXTERNORDERKEY=Left(ltrim(rtrim(ORDERS.EXTERNORDERKEY)),15),             
         ORDERS.ConsigneeKey,             
         ORDERS.Route,         
         MBOL.vessel,             
         MBOLDETAIL.LoadKey,             
         ORDERS.DeliveryDate,             
         ORDERS.C_Company,          
         ORDERS.C_Address1,          
         ORDERS.C_Address2,          
         ORDERS.C_Address3,          
         ORDERS.C_Address4,           city = (ORDERS.C_city + ' '+  ORDERS.C_State   +  ' ' + ORDERS.C_Zip) ,          
         currentpage = @c_currentpage,          
         totalpage = MBOLDETAIL.totalcartons,          
         EObarcode = CASE WHEN ISNULL(CL.SHORT,'') = 'Y' THEN ORDERS.EXTERNORDERKEY ELSE MBOLDETAIL.OrderKey END,   
         showRcode = CASE WHEN ISNULL(CL1.SHORT,'') = 'Y' THEN 
                          CASE WHEN ISNULL(R.UDF01,'') <> '' THEN R.UDF01 ELSE R.code END  --NJOW01
                     ELSE 'Case or Pallet' END,
         showQRcode = CASE WHEN ISNULL(CL2.SHORT,'') = 'Y' THEN Left(ltrim(rtrim(ORDERS.EXTERNORDERKEY)),15) ELSE '' END,
         extordkey_qrcode = CASE WHEN ISNULL(CL2.SHORT,'') = 'Y' THEN(
                            CASE WHEN orders.storerkey = 'AROMA' AND orders.type = 'E' AND Orders.Shipperkey like '%Kerry%' OR Orders.Route like '%Kerry%' 
                            THEN Left(ltrim(RTRIM(REPLACE((ORDERS.EXTERNORDERKEY),'-',''))),15)
                            ELSE Left(ltrim(rtrim(ORDERS.EXTERNORDERKEY)),15) END)
                            ELSE Left(ltrim(rtrim(ORDERS.EXTERNORDERKEY)),15) END  
           
      FROM MBOL(nolock)           
      join MBOLDETAIL (nolock) on (MBOLDETAIL.MBOLKEY=MBOL.MBOLKEY)          
      join orders (nolock) on ( MBOLDETAIL.OrderKey = ORDERS.OrderKey )                 
      left join CODELKUP R (NOLOCK) ON R.Listname = 'DISPATCHTX' AND R.Storerkey = orders.Storerkey                 
                                    AND R.Code = 'LF' AND R.Long = 'r_dw_dispatch_label16'          
      left join CODELKUP CL (NOLOCK) ON CL.Listname = 'REPORTCFG' AND CL.Storerkey = orders.Storerkey                 
                                    AND CL.Code = 'EOBarcode' AND CL.Long = 'r_dw_dispatch_label16'   
      left join CODELKUP CL1 (NOLOCK) ON CL1.Listname = 'REPORTCFG' AND CL1.Storerkey = orders.Storerkey                 
                                    AND CL1.Code = 'ShowRCode' AND CL1.Long = 'r_dw_dispatch_label16' 
      left join CODELKUP CL2 (NOLOCK) ON CL2.Listname = 'REPORTCFG' AND CL2.Storerkey = orders.Storerkey                 
                                    AND CL2.Code = 'ShowQRCode' AND CL2.Long = 'r_dw_dispatch_label16'                                 
      WHERE ( MBOLDETAIL.MBOLKey = @c_MBOLNumber ) and          
            ( MBOLDETAIL.OrderKey = @c_OrderNumber )                  
   --END            
END 





GO