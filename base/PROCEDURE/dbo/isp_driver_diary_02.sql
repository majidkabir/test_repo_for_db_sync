SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_driver_diary_02                                     */
/* Creation Date: 25-Mar-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-12608 - SG - WGSSG - Driver Manifest                    */
/*        :                                                             */
/* Called By: r_dw_driver_diary_02                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_driver_diary_02]
            @c_MBOLKey        NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @c_Storerkey       NVARCHAR(20)
       
   SET @n_Continue  = 1
   SET @n_StartTCnt = 1
       
  /* SELECT Orderkey = ORDERDETAIL.OrderKey,   
          StorerKey = ORDERDETAIL.StorerKey,   
          Company = ORDERS.C_Company,   
          Address1 = ORDERS.C_Address1,   
          Address2 = ORDERS.C_Address2,   
          Address3 = ORDERS.C_Address3,    
          Mbolkey = MBOL.MbolKey,   
          DriverName = MBOL.DRIVERName,   
          VehicleNo = MBOL.Vessel,
          ExternOrderKey = ORDERS.ExternOrderKey,
          InvoiceNo = ORDERS.InvoiceNo,
          RGRNo = '', 
          Remarks=CONVERT(nvarchar(40), MBOL.Remarks), 
          Cartons=CASE WHEN (PACKHEADER.OrderKey = NULL OR PACKHEADER.OrderKey = '') THEN ''
                       ELSE CASE WHEN PACK.CaseCnt > 0 THEN SUM(FLOOR(ORDERDETAIL.ShippedQty)) /  PACK.CaseCnt
                       ELSE 0 END 
                  END,
          SortOrder = '1',
          LineNum = 1  
   FROM ORDERDETAIL (nolock)   
   INNER JOIN ORDERS (nolock) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
   INNER JOIN PACK (nolock) ON ( ORDERDETAIL.PackKey = PACK.PackKey )   
   INNER JOIN MBOL (nolock) ON ( ORDERDETAIL.MBOLKey = MBOL.MbolKey )
   INNER JOIN MBOLDETAIL (nolock) ON ( ORDERDETAIL.ORDERKEY = MBOLDETAIL.ORDERKEY ) 
   LEFT OUTER JOIN PACKHEADER (nolock) ON ( ORDERS.OrderKey = PACKHEADER.OrderKey )
   WHERE ( MBOL.MBOLKEY = @c_MBOLKey )
   GROUP BY ORDERDETAIL.OrderKey,   
           ORDERDETAIL.StorerKey,   
           ORDERS.C_Company,   
           ORDERS.C_Address1,   
           ORDERS.C_Address2,   
           ORDERS.C_Address3,     
           MBOL.MbolKey,   
           MBOL.DRIVERName,    
           MBOL.Vessel, 
           ORDERS.ExternOrderKey, 
           ORDERS.InvoiceNo,
           CONVERT(nvarchar(40), MBOL.Remarks),  
           PACKHEADER.OrderKey, 
           PACK.CaseCnt 
   ORDER BY ORDERDETAIL.OrderKey, SortOrder*/
   /*UNION   
   SELECT Orderkey = ( CASE WHEN RECEIPT.POKEY = ~"~" THEN ~"ZZZ~"
                         ELSE RECEIPT.POKEY
                    END ),   
          StorerKey = RECEIPT.StorerKey,    
          Company = '',   
          Address1 = '', 
          Address2 = '',   
          Address3 = '',    
          MbolKey = RECEIPT.MbolKey,    
          DriverName = MBOL.DRIVERName,    
          VehicleNo = MBOL.Vessel, 
          ExternOrderKey = '', 
          InvoiceNo = '', 
          RGRNo = RECEIPT.ExternReceiptKey, 
          Remarks = CONVERT(nvarchar(40), RECEIPT.Notes),  
          Cartons = 0, 
          SortOrder = '2', 
          LineNum = 0    
   FROM RECEIPT (nolock)
   INNER JOIN MBOL (nolock) ON ( RECEIPT.MBOLKey = MBOL.MbolKey )
   WHERE ( MBOL.MBOLKEY = @c_MBOLKey)*/

   SELECT MBOLDETAIL.MbolKey
        , ISNULL(MBOLDETAIL.UserDefine01,'') AS UserDefine01
        , ISNULL(MBOLDETAIL.UserDefine02,'') AS UserDefine02
        , ISNULL(MBOL.[Route],'') AS [Route]
        , ORDERS.ExternOrderKey
        , ORDERS.InvoiceNo
        , ORDERS.OrderKey
        , ORDERS.StorerKey
        , ORDERS.C_Company
        , ISNULL(ORDERS.C_Address1,'') AS C_Address1
        , ISNULL(ORDERS.C_Address2,'') AS C_Address2
        , ISNULL(ORDERS.C_Address3,'') AS C_Address3
        , SUM(ORDERDETAIL.OriginalQty)
   FROM MBOL (NOLOCK)
   JOIN MBOLDETAIL (NOLOCK) ON MBOLDETAIL.MbolKey = MBOL.MbolKey
   JOIN ORDERS (NOLOCK) ON MBOLDETAIL.OrderKey = ORDERS.OrderKey
   JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
   WHERE MBOL.MbolKey = @c_MBOLKey
   GROUP BY MBOLDETAIL.MbolKey
          , ISNULL(MBOLDETAIL.UserDefine01,'')
          , ISNULL(MBOLDETAIL.UserDefine02,'')
          , ISNULL(MBOL.[Route],'')
          , ORDERS.ExternOrderKey
          , ORDERS.InvoiceNo
          , ORDERS.OrderKey
          , ORDERS.StorerKey
          , ORDERS.C_Company
          , ISNULL(ORDERS.C_Address1,'')
          , ISNULL(ORDERS.C_Address2,'')
          , ISNULL(ORDERS.C_Address3,'')
   ORDER BY ISNULL(MBOLDETAIL.UserDefine01,''), ORDERS.ExternOrderKey

END -- procedure

GO