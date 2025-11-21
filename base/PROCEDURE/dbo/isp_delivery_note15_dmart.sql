SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_Delivery_Note15_dmart    	      		        */
/* Creation Date: 20/11/2017                                            */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-3434 Re-Print report for data has been stored in Datamart*/
/*                                                                      */
/* Called By: r_dw_delivery_note15_dmart                                */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 7.0														    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 22-Mar-2019  WLCHOOI 1.1   WMS-8362 - Add ETA Calculate for Facility */
/*                                       SUB02 and fixed fail to get    */
/*                                       LeadTime (WL01)                */
/* 15-Aug-2019  KarHoe 1.2   INC0807449 - Fix duplicate quantitiy		*/
/************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note15_dmart] (@c_mbolkey NVARCHAR(10))
 AS
 BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    SET ANSI_NULLS ON
    SET ANSI_WARNINGS ON

    DECLARE @sql                NVARCHAR(MAX)
           ,@c_DataMartServerDB NVARCHAR(120)
		     ,@n_StartTCnt        INT
		     ,@n_Continue         INT 
		     ,@c_Orderkey         NVARCHAR(10)
           ,@c_Consigneekey     NVARCHAR(15)
           ,@c_TransMehtod      NVARCHAR(30)
           ,@d_ShipDate4ETA     DATETIME
           ,@d_ETA              DATETIME           
           ,@n_Leadtime         INT
           ,@n_Leadtime1        INT
           ,@n_Leadtime2        INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
           
   --SET @sql = 'SET ANSI_NULLS ON ' + CHAR(13) + 'SET ANSI_WARNINGS ON ' + CHAR(13)
   SET @sql = ''
   
   SELECT @c_DataMartServerDB = ISNULL(NSQLDescrip,'') 
   FROM NSQLCONFIG (NOLOCK)     
   WHERE ConfigKey='DataMartServerDBName'   
   
   IF ISNULL(@c_DataMartServerDB,'') = ''
      SET @c_DataMartServerDB = 'DATAMART'
   
   IF RIGHT(RTRIM(@c_DataMartServerDB),1) <> '.' 
      SET @c_DataMartServerDB = RTRIM(@c_DataMartServerDB) + '.'

	 CREATE TABLE #DO
       (  Facility          NVARCHAR(5)    
       ,  BookingReference  NVARCHAR(30)   
       ,  Vessel            NVARCHAR(30)
       ,  TransMethod       NVARCHAR(30)
       ,  ShipDate          DATETIME    NULL
       ,  ETA               DATETIME    NULL
       ,  Loadkey           NVARCHAR(10)
       ,  Orderkey          NVARCHAR(10)
       ,  ExternOrderkey    NVARCHAR(30)
       ,  ExternPOkey       NVARCHAR(20)
       ,  OrderDate         DATETIME    NULL
       ,  DeliveryDate      DATETIME    NULL
       ,  Consigneekey      NVARCHAR(15)
       ,  C_Company         NVARCHAR(45)
       ,  C_Address1        NVARCHAR(45)
	 	   ,  C_Address2        NVARCHAR(45)
	 	   ,  C_Address3        NVARCHAR(45)
	 	   ,  C_City            NVARCHAR(45)
	 	   ,  C_Zip             NVARCHAR(18)
	 	   ,  C_Phone1          NVARCHAR(18)
	 	   ,  BillToKey         NVARCHAR(15)
	 	   ,  B_Company         NVARCHAR(45)
	 	   ,  B_Address1        NVARCHAR(45)
	 	   ,  B_Address2        NVARCHAR(45)
	 	   ,  B_Address3        NVARCHAR(45)
	 	   ,  B_City            NVARCHAR(45)
	 	   ,  B_Zip             NVARCHAR(18)
	 	   ,  B_Phone1          NVARCHAR(18)
	 	   ,  Notes2            NVARCHAR(4000)
	 	   ,  Storerkey         NVARCHAR(15)
	 	   ,  Sku               NVARCHAR(20)
	 	   ,  SKUDescr          NVARCHAR(60)
	 	   ,  QtyInPCS          INT
	 	   ,  QtyInCS           INT
	 	   ,  Lottable02        NVARCHAR(18)
	 	   ,  Lottable04        DATETIME    NULL
       )		

    CREATE TABLE #LeadTime(
    LeadTime     INT
    )

	 set @sql = @sql  + 'INSERT INTO #DO ('
							+'    Facility '        
							+' ,  BookingReference '
							+' ,  Vessel   '
							+' ,  TransMethod '     
							+' ,  ShipDate '
							+' ,  ETA '
							+' ,  Loadkey  '
							+' ,  Orderkey ' 
							+' ,  ExternOrderkey ' 
							+' ,  ExternPOkey    '  
							+' ,  OrderDate      '  
							+' ,  DeliveryDate   '  
							+' ,  Consigneekey   '  
							+' ,  C_Company  '   
							+' ,  C_Address1 '   
							+' ,  C_Address2 '
							+' ,  C_Address3 '   
							+' ,  C_City     '
							+' ,  C_Zip      '    
							+' ,  C_Phone1   '   
							+' ,  BillToKey  '    
							+' ,  B_Company  '  
							+' ,  B_Address1 '  
							+' ,  B_Address2 '
							+' ,  B_Address3 '
							+' ,  B_City     '   
							+' ,  B_Zip      '  
							+' ,  B_Phone1   ' 
							+' ,  Notes2     '
							+' ,  Storerkey  '
							+' ,  Sku        '
							+' ,  SKUDescr   '
							+' ,  QtyInPCS   '
							+' ,  QtyInCS    '
							+' ,  Lottable02 '
							+' ,  Lottable04 '
							+ ') '
							+'SELECT MBOL.Facility, ' 
							+ ' ISNULL(RTRIM(MBOL.bookingreference),''''), ' 
							+ ' ISNULL(RTRIM(MBOL.vessel),''''), ' 
							+ ' ISNULL(RTRIM(MBOL.TransMethod),''''),  ' 
							+ ' MBOL.ShipDate,    ' 
							+ ' CASE WHEN ISNULL(orders.podarrive,'''') = '''' THEN MBOL.ShipDate ELSE ORDERS.DeliveryDate END,    ' 
							+ ' ISNULL(RTRIM(MBOLDETAIL.Loadkey),''''),    ' 
							+ ' ORDERS.Orderkey,  ' 
							+ ' ISNULL(RTRIM(ORDERS.ExternOrderkey),''''), ' 
							+ ' ISNULL(RTRIM(ORDERS.ExternPOkey),''''),    ' 
							+ ' ORDERS.OrderDate,'
							+ ' ORDERS.DeliveryDate,'
							+ ' ISNULL(RTRIM(ORDERS.Consigneekey),''''),'
							+ ' ISNULL(RTRIM(ORDERS.C_Company),''''),'
							+ ' ISNULL(RTRIM(ORDERS.C_Address1),''''),'
							+ ' ISNULL(RTRIM(ORDERS.C_Address2),''''),'
							+ ' ISNULL(RTRIM(ORDERS.C_Address3),''''),'
							+ ' ISNULL(RTRIM(ORDERS.C_City),''''),'
							+ ' ISNULL(RTRIM(ORDERS.C_Zip),''''),'
							+ ' ISNULL(RTRIM(ORDERS.C_Phone1),''''),'
							+ ' ISNULL(RTRIM(ORDERS.BillToKey),''''),'
							+ ' ISNULL(RTRIM(ORDERS.B_Company),''''),'
							+ ' ISNULL(RTRIM(ORDERS.B_Address1),''''),'
							+ ' ISNULL(RTRIM(ORDERS.B_Address2),''''),'
							+ ' ISNULL(RTRIM(ORDERS.B_Address3),''''),'
							+ ' ISNULL(RTRIM(ORDERS.B_City),''''),'
							+ ' ISNULL(RTRIM(ORDERS.B_Zip),''''),'
							+ ' ISNULL(RTRIM(ORDERS.B_Phone1),''''),'
							+ ' ISNULL(RTRIM(ORDERS.Notes2),''''),'
							+ ' PICKDETAIL.Storerkey,'
							+ ' PICKDETAIL.Sku,'
							+ ' ISNULL(RTRIM(SKU.Descr),''''),'
			            + ' SUM(PICKDETAIL.Qty),'
							+ ' CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN SUM(PICKDETAIL.Qty) / ISNULL(PACK.CaseCnt,0) ELSE 0 END, ' 
							+ ' ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),''''), ' 
							+ ' ISNULL(LOTATTRIBUTE.Lottable04,''1900-01-01'')   ' 
							+  'FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.MBOL MBOL (NOLOCK)      ' 
			            + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.MBOLDETAIL MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLkey = MBOLDETAIL.MBOLkey) '
							-- + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORDERS (NOLOCK) ON ( ORDERS.Mbolkey = MBOLDETAIL.Mbolkey ) ' 	--INC0807449
							+ ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORDERS (NOLOCK) ON ( ORDERS.ORDERKEY = MBOLDETAIL.ORDERKEY) '		--INC0807449
							+ ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PICKDETAIL PICKDETAIL (NOLOCK) ON ( ORDERS.OrderKey = PICKDETAIL.OrderKey ) '
							+ ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE LOTATTRIBUTE (NOLOCK) ON ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot)  '
							+ ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.SKU SKU (NOLOCK) ON ( PICKDETAIL.StorerKey = SKU.Storerkey ) AND  ' 
							+                                       ' (SKU.Sku = PICKDETAIL.Sku ) ' 
							+ ' JOIN '	+ RTRIM(@c_DataMartServerDB) + 'ods.PACK pack WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) '
							+ ' WHERE ( PICKDETAIL.Status >= ''5'' ) AND ' 
							+ '       ( MBOL.Mbolkey = @c_mbolkey )      ' 
							+ ' GROUP BY MBOL.Facility,  ' 
							+ '       ISNULL(RTRIM(MBOL.bookingreference),''''), ' 
							+ '       ISNULL(RTRIM(MBOL.vessel),''''), ' 
							+ '       ISNULL(RTRIM(MBOL.TransMethod),''''),  ' 
							+ '       MBOL.ShipDate,    ' 
							+ '       CASE WHEN ISNULL(orders.podarrive,'''') = '''' THEN MBOL.ShipDate ELSE ORDERS.DeliveryDate END, ' 
							+ '       ISNULL(RTRIM(MBOLDETAIL.Loadkey),''''),    ' 
							+ '       ORDERS.Orderkey,  ' 
							+ '       ISNULL(RTRIM(ORDERS.ExternOrderkey),''''), ' 
							+ '       ISNULL(RTRIM(ORDERS.ExternPOkey),''''),    ' 
							+ ' 	     ORDERS.OrderDate,'
							+ '	     ORDERS.DeliveryDate,'
							+ '	     ISNULL(RTRIM(ORDERS.Consigneekey),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.C_Company),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.C_Address1),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.C_Address2),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.C_Address3),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.C_City),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.C_Zip),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.C_Phone1),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.BillToKey),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.B_Company),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.B_Address1),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.B_Address2),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.B_Address3),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.B_City),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.B_Zip),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.B_Phone1),''''),'
							+ '	     ISNULL(RTRIM(ORDERS.Notes2),''''),'
							+ '	     PICKDETAIL.Storerkey,'
							+ '	     PICKDETAIL.Sku,'
							+ '	     ISNULL(RTRIM(SKU.Descr),''''),'
							+ '	     ISNULL(PACK.CaseCnt,0),'
							+ '	     ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),''''), ' 
							+ '        ISNULL(LOTATTRIBUTE.Lottable04,''1900-01-01'') ' 

		EXEC sp_executesql @sql,                                 
                         N'@c_Mbolkey NVARCHAR(10)', 
                         @c_mbolkey

	 DECLARE CUR_ETA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
    SELECT DISTINCT 
          Orderkey
         ,Consigneekey
         ,TransMethod
         ,ETA
   FROM #DO

   OPEN CUR_ETA

   FETCH NEXT FROM CUR_ETA INTO @c_Orderkey
                              , @c_Consigneekey
                              , @c_TransMehtod
                              , @d_ShipDate4ETA

   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      SET @n_Leadtime = 0
      SET @n_Leadtime1 = 0
      SET @n_Leadtime2 = 0

    /*CS01 Start*/
     /* SELECT @n_Leadtime1 = CASE WHEN ISNUMERIC(Susr1) = 1 THEN Susr1 ELSE 0 END
            ,@n_Leadtime2 = CASE WHEN ISNUMERIC(Susr2) = 1 THEN Susr2 ELSE 0 END
      FROM STORER WITH (NOLOCK)
      WHERE Storerkey = @c_Consigneekey
   
 
      IF @c_TransMehtod IN ('L', 'S4')
      BEGIN
         SET @n_Leadtime = @n_Leadtime1
      END

      IF @c_TransMehtod = 'S3'
      BEGIN
         SET @n_Leadtime = @n_Leadtime2
      END*/
    SET @SQL = ''
    SET @sql = @sql   + ' INSERT INTO #LeadTime '
                      + ' SELECT CASE WHEN MB.transmethod IN (''S4'',''FT'',''L'' ) AND MB.facility=''CBT01'' THEN LEFT(S.SUSR1,2)	'
		                + ' WHEN MB.transmethod IN (''LT'',''S3'') AND MB.facility=''CBT01'' THEN SUBSTRING(S.susr1,4,2)	'
		                + ' WHEN MB.transmethod=''U''  AND MB.facility=''CBT01'' THEN SUBSTRING(S.susr1,7,2)	'
		                + ' WHEN MB.transmethod=''U1'' AND MB.facility=''CBT01'' THEN RIGHT(S.susr1,2)	'                                                 
		                + ' WHEN MB.transmethod IN (''S4'',''FT'',''L'' ) AND MB.facility IN (''SUB01'',''SUB02'') THEN LEFT(S.SUSR2,2)	'   --WL01
		                + ' WHEN MB.transmethod IN (''LT'',''S3'') AND MB.facility IN (''SUB01'',''SUB02'') THEN SUBSTRING(S.SUSR2,4,2)	'   --WL01
		                + ' WHEN MB.transmethod=''U''  AND MB.facility IN (''SUB01'',''SUB02'') THEN SUBSTRING(S.SUSR2,7,2)	'               --WL01
		                + ' WHEN MB.transmethod=''U1'' AND MB.facility IN (''SUB01'',''SUB02'') THEN RIGHT(S.susr2,2)	'                     --WL01                      
		                + ' WHEN MB.transmethod IN (''S4'',''FT'',''L'' ) AND MB.facility=''MLG01'' THEN LEFT(S.SUSR3,2)	'
		                + ' WHEN MB.transmethod IN (''LT'',''S3'') AND MB.facility=''MLG01'' THEN SUBSTRING(S.SUSR3,4,2)	'
		                + ' WHEN MB.transmethod=''U''  AND MB.facility=''MLG01'' THEN SUBSTRING(S.SUSR3,7,2)	'
		                + ' WHEN MB.transmethod=''U1'' AND MB.facility=''MLG01'' THEN RIGHT(S.susr3,2)	ELSE 0 END'
		                + ' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORD (NOLOCK) ' 
		                + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.MBOL MB (NOLOCK) ON ( ORD.Mbolkey = MB.Mbolkey ) '
		                + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.Storer S (NOLOCK) ON ( S.storerkey = ORD.Consigneekey ) 
                                                                 AND ORD.Orderkey = @c_Orderkey'

		EXEC sp_executesql @sql,                                 
								  N'@c_Orderkey NVARCHAR(10)',           --WL01
								  @c_Orderkey--,                         --WL01
                --@n_Leadtime                            --WL01

      SELECT TOP 1 @n_Leadtime = Leadtime from #LeadTime --WL01

      DELETE FROM #Leadtime                              --WL01 

 /*CS01 END*/
    SET @d_ETA = CONVERT(NVARCHAR(10),DATEADD(d, @n_Leadtime, @d_ShipDate4ETA),112)
		SET @SQL = ''
	
    SET @SQL = '  WHILE 1 = 1 '
             + ' BEGIN '
         --IF DATEPART(DW, @d_ETA) <> 1     --  Sunday = 1
         --BEGIN
         --   BREAK
         --END
   
            +' IF NOT EXISTS (SELECT 1 '
				+ ' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.HOLIDAYDETAIL HOLIDAYDETAIL WITH (NOLOCK)'
				+ ' WHERE HOLIDAYDETAIL.Holidaydate = @d_ETA' + ')' 
			 	+ ' AND DATEPART(DW, @d_ETA) <> ' + '1'    --(CS01)
            + ' BEGIN '
            + ' BREAK '
            + ' END  '
            + ' SET @d_ETA = DATEADD(d, 1, @d_ETA)   '              
            + ' END '

	    EXEC sp_executesql @sql,                                 
								  N'@d_ETA DATETIME', 
								  @d_ETA
   
      UPDATE #DO 
      SET ETA = @d_ETA
      WHERE Orderkey = @c_Orderkey

      FETCH NEXT FROM CUR_ETA INTO @c_Orderkey
                                 , @c_Consigneekey
                                 , @c_TransMehtod
                                 , @d_ShipDate4ETA
 
   END
   CLOSE CUR_ETA
   DEALLOCATE CUR_ETA

   SELECT 
         Facility          
      ,  BookingReference  
      ,  Vessel   
      ,  ShipDate         
      ,  ETA  
      ,  Loadkey           
      ,  Orderkey          
      ,  ExternOrderkey    
      ,  ExternPOkey       
      ,  OrderDate         
      ,  DeliveryDate      
      ,  Consigneekey      
      ,  C_Company         
      ,  C_Address1        
		,  C_Address2 
		,  C_Address3        
		,  C_City            
		,  C_Zip             
		,  C_Phone1          
		,  BillToKey         
		,  B_Company         
		,  B_Address1        
		,  B_Address2  
		,  B_Address3      
		,  B_City        
		,  B_Zip             
		,  B_Phone1          
		,  Notes2            
		,  Storerkey         
		,  Sku               
		,  SKUDescr          
		,  QtyInPCS          
		,  QtyInCS           
		,  Lottable02        
		,  Lottable04
   FROM #DO   
   ORDER BY Orderkey
           ,Storerkey     
	         ,Sku

QUIT:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_ETA') in (0 , 1)  
   BEGIN
      CLOSE CUR_ETA
      DEALLOCATE CUR_ETA
   END

END -- procedure

GO