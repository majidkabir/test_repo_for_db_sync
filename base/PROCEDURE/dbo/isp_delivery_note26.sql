SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Delivery_Note26        	      		         */
/* Creation Date: 23/03/2018                                            */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-4253 - New RCM for DN                                   */
/*                                                                      */
/* Called By: r_dw_delivery_note26                                      */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0														               */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date			Author    Ver    Purposes                                */
/* 11-04-2018  LZG		 1.1    Fix incorrect CS Qty - INC0193272 (ZG01)*/
/* 02-05-2018  LZG       1.2    INC0217474 - Fixed Heterogenous Quries  */
/*                              error (ZG01)                            */
/* 31-07-2018  CHEEMUN   1.3    INC0326908-Orders.Orderkey Join 		   */
/*			                       MBOLDetail.Orderkey, SUM(Pickdetail.Qty)*/ 
/************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note26] (@c_mbolkey NVARCHAR(10)
                                ,@c_rpttype NVARCHAR(50) = '')
 AS
 BEGIN
    
   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS ON

    DECLARE @sql                NVARCHAR(MAX)
           ,@sqlinsert          NVARCHAR(MAX)
           ,@sqlselect          NVARCHAR(MAX)
           ,@sqlfrom            NVARCHAR(MAX)
           ,@sqlwhere           NVARCHAR(MAX) 
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
           ,@c_dmartreport      NVARCHAR(10)
           ,@c_logo             NVARCHAR(200)
           ,@c_storerkey        NVARCHAR(20)
           ,@c_STCompany        NVARCHAR(45)
           ,@c_STAdd1           NVARCHAR(45)
           ,@c_STAdd2           NVARCHAR(45)
           ,@c_STAdd3           NVARCHAR(45)
           ,@c_STAdd4           NVARCHAR(45)
           ,@c_Showlot02and04   NVARCHAR(1)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
           
   --SET @sql = 'SET ANSI_NULLS ON ' + CHAR(13) + 'SET ANSI_WARNINGS ON ' + CHAR(13)
   SET @sql = ''
   SET @c_dmartreport = 'N'
   
   IF @c_rpttype = 'dmart'
   BEGIN
   	SET @c_dmartreport = 'Y'
   END
   
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
	 	 ,  QtyInCS           DECIMAL
	 	 ,  Lottable02        NVARCHAR(18)
	 	 ,  Lottable04        DATETIME    NULL
	 	 ,  Clogo             NVARCHAR(200) NULL
	 	 ,  ST_Company         NVARCHAR(45)
	 	 ,  ST_Address1        NVARCHAR(45)
	 	 ,  ST_Address2        NVARCHAR(45)
	 	 ,  ST_Address3        NVARCHAR(45)
	 	 ,  ST_Address4        NVARCHAR(45)
	 	 ,  ST_City            NVARCHAR(45)
	 	 ,  ST_Zip             NVARCHAR(45)
	 	 ,  ST_Phone1          NVARCHAR(45)
	 	 ,  ST_Fax1            NVARCHAR(45)
	 	 ,  OthReference       NVARCHAR(30)
	 	 ,  OHNotes            NVARCHAR(4000)
	 	 ,  UOM                NVARCHAR(10)
	 	 ,  Showlot02and04     NVARCHAR(1)
       )		


		SET @c_logo = ''
		SET @c_storerkey = ''
		
		SELECT TOP 1 @c_storerkey = ORD.Storerkey
		FROM ORDERS ORD WITH (NOLOCK)
		WHERE ORD.MBOLKey=@c_mbolkey 
		
		SELECT @c_logo = ISNULL(C.notes2,'')
		FROM CODELKUP C WITH (NOLOCK)
		WHERE listname = 'RPTLOGO'
		AND long = 'isp_Delivery_Note26'
		AND Storerkey = @c_Storerkey    
		

      SET @c_Showlot02and04 = 'N' 
      
      SELECT @c_Showlot02and04 = CASE WHEN (CL.Short IS NULL OR CL.Short = 'N') THEN 'N' ELSE 'Y' END
      FROM CODELKUP CL WITH (NOLOCK) 
      WHERE CL.ListName = 'REPORTCFG' AND CL.Long = 'isp_Delivery_Note26'
      AND CL.Code = 'SHOWLOT02AND04' AND CL.Storerkey =@c_Storerkey
   


		SELECT @c_STCompany = ST.Company
		      ,@c_STAdd1 = ISNULL(ST.Address1,'')
		      ,@c_STAdd2 = ISNULL(ST.Address2,'')
		      ,@c_STAdd3 = ISNULL(ST.Address3,'')
		      ,@c_STAdd4 = ISNULL(ST.Address4,'')
		FROM STORER ST (NOLOCK)
		WHERE ST.StorerKey = @c_storerkey


	 set @sqlinsert   = N'INSERT INTO #DO ('
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
							+' ,  Clogo      '
							+' ,  ST_Company '
							+' ,  ST_Address1'
							+' ,  ST_Address2'
							+' ,  ST_Address3'
							+' ,  ST_Address4'
							+' ,  ST_city'
							+' ,  ST_zip'
							+' ,  ST_phone1'
							+' ,  ST_fax1'
							+' ,  OthReference'
							+' ,  OHNotes,UOM,Showlot02and04 '
							+ ') '
							
SET @sqlselect =  N'SELECT MBOL.Facility, ' 
							+ ' ISNULL(RTRIM(MBOL.Equipment),''''), ' 
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
			            + ' SUM(PICKDETAIL.Qty),'  --INC0326908
							--+ ' CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN (PICKDETAIL.Qty) / ISNULL(PACK.CaseCnt,0) ELSE (PICKDETAIL.Qty) END, ' 
							+  ' CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN SUM(PICKDETAIL.Qty) / ISNULL(PACK.CaseCnt,0) ELSE SUM(PICKDETAIL.Qty) END, '				-- ZG01
							+ ' ISNULL(RTRIM(LOTATTRIBUTE.Lottable02),''''), ' 
							+ ' ISNULL(LOTATTRIBUTE.Lottable04,''1900-01-01'') ,@c_logo ,'
							+ ' ST.Company,ISNULL(ST.Address1,''''),ISNULL(ST.Address2,''''),ISNULL(ST.Address3,''''),ISNULL(ST.Address4,''''),'
							+ ' ISNULL(ST.City,''''),ISNULL(ST.Zip,''''),ISNULL(ST.phone1,''''),ISNULL(ST.Fax1 ,''''),' 
							+ ' ISNULL(RTRIM(MBOL.OtherReference),''''), ISNULL(RTRIM(ORDERS.Notes),'''') , ' 
							+ ' CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN PACK.PACKUOM1 ELSE PACK.PACKUOM3 END,@c_Showlot02and04'
							
	IF @c_dmartreport = 'Y'
	BEGIN						
	SET @sqlfrom = N' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.MBOL MBOL (NOLOCK)      ' 
			            + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.MBOLDETAIL MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLkey = MBOLDETAIL.MBOLkey) '  
       					+ ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORDERS (NOLOCK) ON ( ORDERS.Mbolkey = MBOLDETAIL.Mbolkey AND '
       					+ '                                        ORDERS.LoadKey = MBOLDETAIL.LoadKey AND ORDERS.ORDERKEY = MBOLDETAIL.ORDERKEY) ' --INC0326908  
       					+ ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PICKDETAIL PICKDETAIL (NOLOCK) ON ( ORDERS.OrderKey = PICKDETAIL.OrderKey ) '  
       					+ ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.LOTATTRIBUTE LOTATTRIBUTE (NOLOCK) ON ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot) AND '
      					+ '                                                                                   ( LOTATTRIBUTE.STORERKEY = ORDERS.STORERKEY AND LOTATTRIBUTE.SKU = ORDERDETAIL.SKU) ' --INC0326908
       					+ ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.SKU SKU (NOLOCK) ON ( PICKDETAIL.StorerKey = SKU.Storerkey ) AND  '   
       					+ '                                       (SKU.Sku = PICKDETAIL.Sku ) '   
       					+ ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.PACK pack WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) '  
       					+ ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.Storer ST WITH (NOLOCK) ON (ST.storerkey = ORDERS.Storerkey) '  
	END
	ELSE
	BEGIN
		SET @sqlfrom = N' FROM MBOL MBOL (NOLOCK)      ' 
			            + ' JOIN MBOLDETAIL MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLkey = MBOLDETAIL.MBOLkey) '  
       					+ ' JOIN ORDERS ORDERS (NOLOCK) ON ( ORDERS.Mbolkey = MBOLDETAIL.Mbolkey AND '
       					+ '                                  ORDERS.LoadKey = MBOLDETAIL.LoadKey AND ORDERS.ORDERKEY = MBOLDETAIL.ORDERKEY) ' --INC0326908  
       					+ ' JOIN ORDERDETAIL ORDERDETAIL (NOLOCK) ON ( ORDERS.Orderkey = ORDERDETAIL.Orderkey ) '  
       					+ ' JOIN PICKDETAIL PICKDETAIL (NOLOCK) ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey '  
       					+ '                            AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber AND ORDERDETAIL.SKU =PICKDETAIL.SKU  ) '  
       					+ ' JOIN LOTATTRIBUTE LOTATTRIBUTE (NOLOCK) ON ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot)  AND '  
       					+ '                                            ( LOTATTRIBUTE.STORERKEY = ORDERS.STORERKEY AND LOTATTRIBUTE.SKU = ORDERDETAIL.SKU) ' --INC0326908
       					+ ' JOIN SKU SKU (NOLOCK) ON ( PICKDETAIL.StorerKey = SKU.Storerkey ) AND  '   
       					+ '                          (SKU.Sku = PICKDETAIL.Sku ) '   
       					+ ' JOIN PACK pack WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey) '  
       					+ ' JOIN Storer ST WITH (NOLOCK) ON (ST.storerkey = ORDERS.Storerkey) '  
	END							
	
	SET @sqlwhere =  N' WHERE ( PICKDETAIL.Status >= ''5'' ) AND ' 
							+ '       ( MBOL.Mbolkey = @c_mbolkey )      ' 
							+ ' GROUP BY MBOL.Facility,  ' 
							+ '       ISNULL(RTRIM(MBOL.Equipment),''''), ' 
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
							+ '        ISNULL(LOTATTRIBUTE.Lottable04,''1900-01-01''), ' 
							+ '        ST.Company,ISNULL(ST.Address1,''''),ISNULL(ST.Address2,''''),ISNULL(ST.Address3,''''),ISNULL(ST.Address4,''''),'
							+ '        ISNULL(ST.City,''''),ISNULL(ST.Zip,''''),ISNULL(ST.phone1,''''),ISNULL(ST.Fax1 ,''''),' 
							+ '       ISNULL(RTRIM(MBOL.OtherReference),''''),ISNULL(RTRIM(ORDERS.Notes),''''), ' 
							+ ' CASE WHEN ISNULL(PACK.CaseCnt,0) > 0 THEN PACK.PACKUOM1 ELSE PACK.PACKUOM3 END'
							
 SET @sql = @sqlinsert + CHAR(13) + @sqlselect	+ CHAR(13) + @sqlfrom + CHAR(13) + @sqlwhere						

 EXEC sp_executesql @sql,                                 
                    N'@c_Mbolkey NVARCHAR(10),@c_logo NVARCHAR(200),@c_Showlot02and04 NVARCHAR(1)', 
                     @c_mbolkey,@c_logo,@c_Showlot02and04

      --select @sql
      --SELECT LEN(@SQL)
      --GOTO Quit

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
    SET @sql = @sql  + 'SELECT  @n_Leadtime = CASE WHEN MB.transmethod IN (''S4'',''FT'',''L'' ) AND MB.facility=''CBT01'' THEN LEFT(S.SUSR1,2)	'
		               + ' WHEN MB.transmethod IN (''LT'',''S3'') AND MB.facility=''CBT01'' THEN SUBSTRING(S.susr1,4,2)	'
		               + ' WHEN MB.transmethod=''U''  AND MB.facility=''CBT01'' THEN SUBSTRING(S.susr1,7,2)	'
		               + ' WHEN MB.transmethod=''U1'' AND MB.facility=''CBT01'' THEN RIGHT(S.susr1,2)	'                                                 
		               + ' WHEN MB.transmethod IN (''S4'',''FT'',''L'' ) AND MB.facility=''SUB01'' THEN LEFT(S.SUSR2,2)	'
		               + ' WHEN MB.transmethod IN (''LT'',''S3'') AND MB.facility=''SUB01'' THEN SUBSTRING(S.SUSR2,4,2)	'
		               + ' WHEN MB.transmethod=''U''  AND MB.facility=''SUB01'' THEN SUBSTRING(S.SUSR2,7,2)	'
		               + ' WHEN MB.transmethod=''U1'' AND MB.facility=''SUB01'' THEN RIGHT(S.susr2,2)	'                                                 
		               + ' WHEN MB.transmethod IN (''S4'',''FT'',''L'' ) AND MB.facility=''MLG01'' THEN LEFT(S.SUSR3,2)	'
		               + ' WHEN MB.transmethod IN (''LT'',''S3'') AND MB.facility=''MLG01'' THEN SUBSTRING(S.SUSR3,4,2)	'
		               + ' WHEN MB.transmethod=''U''  AND MB.facility=''MLG01'' THEN SUBSTRING(S.SUSR3,7,2)	'
		               + ' WHEN MB.transmethod=''U1'' AND MB.facility=''MLG01'' THEN RIGHT(S.susr3,2)	ELSE 0 END'
		               + ' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.ORDERS ORD (NOLOCK) ' 
		               + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.MBOL MB (NOLOCK) ON ( ORD.Mbolkey = MB.Mbolkey ) '
		               + ' JOIN ' + RTRIM(@c_DataMartServerDB) + 'ods.Storer S (NOLOCK) ON ( S.storerkey = ORD.Consigneekey ) 
                                                                 AND ORD.Orderkey = @c_Orderkey'

		EXEC sp_executesql @sql,                                 
								  N'@c_Orderkey NVARCHAR(10), @n_Leadtime INT', 
								  @c_Orderkey,
								  @n_Leadtime


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

	IF @c_Showlot02and04 = 'Y'
	BEGIN
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
		,  Clogo
		,ST_Company, ST_Address1, ST_Address2, ST_Address3, ST_Address4
		,ST_City, ST_Zip, ST_Phone1, ST_Fax1,OthReference,OHNotes,UOM,Showlot02and04
   FROM #DO   
   ORDER BY Orderkey
           ,Storerkey     
	         ,Sku
	         ,Lottable02
	END
	ELSE
	BEGIN
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
		,  sum(QtyInPCS) AS    QtyInPCS       
		,  sum(QtyInCS) AS  QtyInCS          
		,  MIN(Lottable02) AS Lottable02        
		,  MIN(Lottable04) AS Lottable04
		,  Clogo
		,ST_Company, ST_Address1, ST_Address2, ST_Address3, ST_Address4
		,ST_City, ST_Zip, ST_Phone1, ST_Fax1,OthReference,OHNotes,UOM,Showlot02and04
   FROM #DO   
		GROUP BY  
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
		,  Clogo
		,ST_Company, ST_Address1, ST_Address2, ST_Address3, ST_Address4
		,ST_City, ST_Zip, ST_Phone1, ST_Fax1,OthReference,OHNotes,UOM,Showlot02and04
   ORDER BY Orderkey
           ,Storerkey     
	         ,Sku
	         ,Lottable02
	END		         

QUIT:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_ETA') in (0 , 1)  
   BEGIN
      CLOSE CUR_ETA
      DEALLOCATE CUR_ETA
   END

END -- procedure

GO