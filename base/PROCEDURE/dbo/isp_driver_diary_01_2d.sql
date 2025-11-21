SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_driver_diary_01_2d                             */
/* Creation Date: 2012-07-17                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#247809 - SG ePOD, 2D barcode in Drivers Diary report    */
/*                                                                      */
/* Called By: r_dw_driver_dialy_01_2d                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver.  Purposes                                 */
/************************************************************************/

CREATE PROC [dbo].[isp_driver_diary_01_2d] (
    @c_mbolkey NVARCHAR(10)
 )
 AS
 BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF   
 
   DECLARE @c_orderkey   NVARCHAR(10),
           @c_epodweburl NVARCHAR(120),
           @c_epodweburlparam NVARCHAR(250)
      
   SELECT @c_epodweburl = NSQLDescrip
   FROM NSQLCONFIG (NOLOCK)
   WHERE Configkey = 'EPODWEBURL'

   SELECT Orderkey=ORDERDETAIL.OrderKey,   
          StorerKey=ORDERDETAIL.StorerKey,   
          Company=ORDERS.C_Company,   
          Address1=ORDERS.C_Address1,   
          Address2=ORDERS.C_Address2,   
          Address3=ORDERS.C_Address3,    
          Mbolkey=MBOL.MbolKey,   
          DriverName=MBOL.DRIVERName,   
          VehicleNo=MBOL.Vessel,
          ExternOrderKey=ORDERS.ExternOrderKey,
          InvoiceNo=ORDERS.InvoiceNo,
   		    RGRNo='', 
   		    Remarks=CONVERT(char(40), MBOL.Remarks), 
          SortOrder='1',
          LineNum=1,  
          Route=ORDERS.Route,
          Pmt=ORDERS.PmtTerm,
          Bag=MBOLDETAIL.UserDefine01,
          Carton=MBOLDETAIL.UserDefine02,
          Pallet=MBOLDETAIL.UserDefine03,
          ConsigneeKey= ORDERS.ConsigneeKey,
          Remarks1=ISNULL(Convert(char(125), ORDERS.Notes),''),
          Remarks2=ISNULL(Convert(char(125), ORDERS.Notes2),''),
          OrderType=ORDERS.Type,
          ORDQty= SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty),
          epodfullurl=@c_epodweburlparam   
   INTO #RESULT
   FROM ORDERDETAIL (nolock)   
   INNER JOIN ORDERS (nolock) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
   INNER JOIN PACK (nolock) ON ( ORDERDETAIL.PackKey = PACK.PackKey )   
   INNER JOIN MBOL (nolock) ON ( ORDERDETAIL.MBOLKey = MBOL.MbolKey )
   INNER JOIN MBOLDETAIL (nolock) ON ( ORDERDETAIL.ORDERKEY = MBOLDETAIL.ORDERKEY ) 
   LEFT OUTER JOIN PACKHEADER (nolock) ON ( ORDERS.OrderKey = PACKHEADER.OrderKey )
   WHERE ( MBOL.MBOLKEY = @c_mbolkey )
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
            CONVERT(char(40), MBOL.Remarks),  
            PACKHEADER.OrderKey, 
            ORDERS.Route,
            ORDERS.PmtTerm,
            MBOLDETAIL.UserDefine01,
            MBOLDETAIL.UserDefine02,
            MBOLDETAIL.UserDefine03,    
            ORDERS.ConsigneeKey,
            ISNULL(Convert(char(125), ORDERS.Notes),''),
            ISNULL(Convert(char(125), ORDERS.Notes2),''),
            ORDERS.Type   
   UNION   
   SELECT Orderkey= ( CASE WHEN RECEIPT.POKEY = '' THEN 'ZZZ'
                           ELSE RECEIPT.POKEY
                      END ),   
          StorerKey=RECEIPT.StorerKey,    
          Company='',   
          Address1='', 
          Address2='',   
          Address3='',    
          MbolKey=RECEIPT.MbolKey,    
          DriverName=MBOL.DRIVERName,    
          VehicleNo=MBOL.Vessel, 
          ExternOrderKey='', 
          InvoiceNo='', 
          RGRNo=RECEIPT.ExternReceiptKey, 
   		    Remarks=CONVERT(char(40), RECEIPT.Notes),  
          SortOrder='2', 
          LineNum=0,
          Route='',
          Pmt='',
          Bag='',
          Carton='',
          Carton='' ,
          ConsigneeKey='',
          Remarks1='',
          Remarks2='',
          OrderType='',
          ORDQty=0,     
          epodfullurl=@c_epodweburlparam   
   FROM RECEIPT (nolock)
   INNER JOIN MBOL (nolock) ON ( RECEIPT.MBOLKey = MBOL.MbolKey )
   WHERE ( MBOL.MBOLKEY = @c_mbolkey )  
         
   DECLARE cur_1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT orderkey FROM #RESULT
   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_orderkey
   WHILE (@@fetch_status <> -1)
   BEGIN      
      SET @c_epodweburlparam = 'SG|'+RTRIM(@c_Orderkey)
      
      IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fnc_EncryptURLQueryString]'))       
         SET @c_epodweburlparam = dbo.fnc_EncryptURLQueryString(@c_epodweburlparam,'P@sSw0rd')
      ELSE IF EXISTS (SELECT * FROM MASTER.sys.objects WHERE object_id = OBJECT_ID(N'[Master].[dbo].[fnc_EncryptURLQueryString]'))
         SET @c_epodweburlparam = MASTER.dbo.fnc_EncryptURLQueryString(@c_epodweburlparam,'P@sSw0rd')        
         
      UPDATE #RESULT
      SET epodfullurl = RTRIM(@c_epodweburl)+RTRIM(@c_epodweburlparam)
      WHERE mbolkey = @c_mbolkey
      AND orderkey = @c_orderkey

      FETCH NEXT FROM cur_1 INTO @c_orderkey
   END
   CLOSE cur_1
   DEALLOCATE cur_1

   SELECT *
   FROM #RESULT
   ORDER BY Orderkey

   DROP TABLE #RESULT
 END

GO