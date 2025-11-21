SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_LoadManifestSum06                              */  
/* Creation Date: 27-Jun-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 247851 - PH Load Manifest Summary                           */  
/*                                                                      */  
/* Called By: PB dw: r_dw_dmanifest_sum06 (RCM ReportType 'MANSUM')     */  
/*                                                                      */  
/* PVCS Version: 1.10                                                   */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/* 02-APR-2019  WLCHOOI    WMS-8458 - NK_PH Load Manifest Report (WL01) */
/* 20-Jul-2019  NJOW01     Fix description length                       */ 
/* 17-JUL-2019  CSCHONG    WMS-9796 - NIKEPH Load Manifest Re-Print(CS01)*/
/************************************************************************/  
  
CREATE PROC [dbo].[isp_LoadManifestSum06] (  
    @c_mbolkey NVARCHAR(10)  
 )  
 AS  
 BEGIN  
    SET NOCOUNT ON         -- SQL 2005 Standard
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF    
    
    DECLARE @n_totalorders   int,  
            @n_totalcust     int,  
            @n_totalqty      int,  
            @c_orderkey      NVARCHAR(10),  
            @dc_totalwgt     decimal(7,2),  
            @c_orderkey2     NVARCHAR(10),  
            @c_prevorder     NVARCHAR(10),  
            @c_pickdetailkey NVARCHAR(18),  
            @c_sku           NVARCHAR(20),  
            @dc_skuwgt       decimal(7,2),  
            @n_carton        int,  
            @n_totalcarton   int,  
            @n_each          int,      
            @n_totaleach     int,
            @c_ProductEngine NVARCHAR(100),       --WL01
            @c_ShowField     NVARCHAR(1),         --WL01
            @c_BUSR7         NVARCHAR(50)         --WL01  
            

 /*CS01 Start*/			 
 DECLARE @c_ExecStatements   NVARCHAR(4000), 
         @c_ExecArguments    NVARCHAR(4000), 
         @c_arcdbname        NVARCHAR(50),        
	     @c_storerkey        NVARCHAR(20),        
		 @c_getOrdkey        NVARCHAR(20),
		 @c_RetriveArchDB    NVARCHAR(5),
		 @c_CustomerGroupName NVARCHAR(60),
		 @c_GetFrmArchDB      NVARCHAR(5),
		 @c_MBOLORDKey        NVARCHAR(20),
		 @c_ChkStorerkey      NVARCHAR(20),
		 @c_StorerkeyOut      NVARCHAR(20),
		 @c_GetCustGrpName    NVARCHAR(60),
		 @c_GetExtPOKEY       NVARCHAR(50)        

 /*CS01 END*/
			 
         
         
   CREATE TABLE #TMP_MBLOAD
      (  RowID                INT NOT NULL IDENTITY(1,1) PRIMARY KEY
      ,  vessel               NVARCHAR(255)
      ,  Orderkey             NVARCHAR(20)
      ,  Storerkey            NVARCHAR(15)
      ,  MBOLKEY              NVARCHAR(10)
      ,  carrierkey           NVARCHAR(20)
      ,  Departuredate        DATETIME
      ,  CarrierAgent         NVARCHAR(30)
      ,  PlaceOfDelivery      NVARCHAR(30)
      ,  PlaceOfDischarge     NVARCHAR(30) 
      ,  OtherReference       NVARCHAR(30)
      ,  DriverName           NVARCHAR(30)
      ,  TransMethod          NVARCHAR(30)
      ,  PlaceOfLoading       NVARCHAR(30)
      ,  Remarks              NVARCHAR(4000)
      ,  EditWho              NVARCHAR(30)
      ,  Loadkey              NVARCHAR(20)
      ,  externorderkey       NVARCHAR(50)
      ,  [description]        NVARCHAR(50)
      ,  DeliveryDate         DATETIME
      ,  totalcartons         INT
      ,  DESCR                NVARCHAR(50) 
	  ,  ExternPOKEY          NVARCHAR(50)
	  ,  CustomerGroupName    NVARCHAR(60)
	  ,  ShowField            NVARCHAR(10)
      ,  FromArchDB           NVARCHAR(10)
      
      )   

	  /*CS01 start*/
	  SET @c_storerkey = ''
      SET @c_getOrdkey = ''
	  SET @c_CustomerGroupName = ''
	  SET @c_ShowField = ''

      SELECT @c_arcdbname = NSQLValue FROM NSQLCONFIG (NOLOCK)
      WHERE ConfigKey='ArchiveDBName'

      IF ISNULL(@c_arcdbname,'') = ''
      BEGIN
         SET @c_arcdbname = 'ARCHIVE'
      END

	  IF EXISTS (SELECT 1 FROM MBOLDETAIL (NOLOCK) WHERE Mbolkey = @c_mbolkey)
      BEGIN
	     INSERT INTO #TMP_MBLOAD (vessel,  Orderkey, storerkey, MBOLKEY,  carrierkey,  Departuredate,  CarrierAgent,  PlaceOfDelivery                  
                                   ,  PlaceOfDischarge,  OtherReference,  DriverName,  TransMethod,  PlaceOfLoading,  Remarks                    
                                   ,  EditWho,  Loadkey,  externorderkey,  [description],  DeliveryDate,  totalcartons,  DESCR                    
                                   ,  ExternPOKEY , CustomerGroupName,ShowField , FromArchDB)

        SELECT DISTINCT  
           vessel = MBOL.vessel, 
		   MBOLDETAIL.orderkey,
		   Orders.StorerKey,   
		   MBOL.mbolkey,  
           MBOL.carrierkey, 
		   MBOL.Departuredate, 
		   MBOL.CarrierAgent,    
           MBOL.PlaceOfDelivery, 
           MBOL.PlaceOfDischarge,
           MBOL.OtherReference,  
           MBOL.DriverName,      
           MBOL.TransMethod,     
           MBOL.PlaceOfLoading,  
           MBOL.Remarks,
		   MBOL.EditWho,
           MBOLDETAIL.loadkey,   
           MBOLDETAIL.externorderkey,  
            --MBOLDETAIL.description,    
           ORDERS.C_Company AS description, --NJOW01  
           MBOLDETAIL.deliverydate,    
           mboldetail.totalcartons,    
           FACILITY.Descr,  
		   ExternPOKey = ORDERS.ExternPOKey, 
           STORER.CustomerGroupName, 
           ShowField = ISNULL(CL.SHORT,'N'), 
		   'N'                                     
      FROM MBOL (NOLOCK) 
      JOIN MBOLDETAIL (NOLOCK)  
          ON MBOL.mbolkey = MBOLDETAIL.mbolkey  
      LEFT OUTER JOIN ORDERS (NOLOCK) 
          ON MBOL.MbolKey = ORDERS.MBOLKey AND   
             MBOLDETAIL.OrderKey = ORDERS.OrderKey
      JOIN FACILITY (NOLOCK) ON MBOL.Facility = FACILITY.Facility 
      LEFT JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey 
      LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'ShowField'                                   
                                  AND CL.Long = 'r_dw_dmanifest_sum06' AND CL.STORERKEY = ORDERS.Storerkey                  
      WHERE MBOL.mbolkey = @c_mbolkey   
	END
	ELSE
	BEGIN

	  SET @c_ExecStatements = ''
	  SELECT @c_ExecStatements = N'SELECT DISTINCT vessel = MBOL.vessel, MBOLDETAIL.orderkey, Orders.StorerKey, MBOL.mbolkey, ' 
                               +' MBOL.carrierkey,MBOL.Departuredate,MBOL.CarrierAgent,MBOL.PlaceOfDelivery,MBOL.PlaceOfDischarge, '
                               +' MBOL.OtherReference,MBOL.DriverName,MBOL.TransMethod,MBOL.PlaceOfLoading,MBOL.Remarks,MBOL.EditWho,'
                               +' MBOLDETAIL.loadkey,MBOLDETAIL.externorderkey,MBOLDETAIL.description,MBOLDETAIL.deliverydate,'
							   +' mboldetail.totalcartons,FACILITY.Descr,ExternPOKey = ORDERS.ExternPOKey,STORER.CustomerGroupName,' 
                               +' ShowField = ISNULL(CL.SHORT,''N''), ''Y''     ' 
	  SELECT @c_ExecStatements = ISNULL(RTRIM(@c_ExecStatements),'') + ' '+' FROM '+ ISNULL(RTRIM(@c_arcdbname),'') + '.dbo.MBOL (NOLOCK) '
	                         + '  JOIN '+ ISNULL(RTRIM(@c_arcdbname),'') + '.dbo.MBOLDETAIL (NOLOCK) ON MBOL.mbolkey = MBOLDETAIL.mbolkey' 
							 + '  LEFT OUTER JOIN '+ ISNULL(RTRIM(@c_arcdbname),'') + '.dbo.ORDERS (NOLOCK) ON MBOL.mbolkey = ORDERS.mbolkey' 
							 + '  AND MBOLDETAIL.OrderKey = ORDERS.OrderKey '
							 + '  JOIN FACILITY (NOLOCK) ON MBOL.Facility = FACILITY.Facility ' 
							 + '  LEFT JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey '
							 + '  LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = ''REPORTCFG'' AND CL.CODE = ''ShowField''   '
							 + '  AND CL.Long = ''r_dw_dmanifest_sum06'' AND CL.STORERKEY = ORDERS.Storerkey  '   
							 + '  WHERE MBOL.mbolkey = @c_mbolkey '  
							 
							 
	SET @c_ExecArguments = N'@c_arcdbname   NVARCHAR(50)'  
	                       +',@c_mbolkey    NVARCAR(20) '
                                    

     INSERT INTO #TMP_MBLOAD (vessel,  Orderkey, storerkey, MBOLKEY,  carrierkey,  Departuredate,  CarrierAgent,  PlaceOfDelivery                  
                                   ,  PlaceOfDischarge,  OtherReference,  DriverName,  TransMethod,  PlaceOfLoading,  Remarks                    
                                   ,  EditWho,  Loadkey,  externorderkey,  [description],  DeliveryDate,  totalcartons,  DESCR                    
                                   ,  ExternPOKEY , CustomerGroupName, ShowField , FromArchDB)
	 EXEC sp_executesql @c_ExecStatements,                                 
                        N'@c_mbolkey NVARCHAR(20)', 
                          @c_mbolkey


   END

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Orderkey,Storerkey,FromArchDB   
   FROM   #TMP_MBLOAD    
   WHERE mbolkey = @c_mbolkey  
   AND ISNULL(Storerkey,'') = ''
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_mbolordkey,@c_chkstorerkey,@c_GetFrmArchDB    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   

    SET @c_StorerkeyOut= ''
	SET @c_GetCustGrpName = ''
	SET @c_GetExtPOKEY = ''

   IF ISNULL(@c_chkstorerkey,'') = '' 
   BEGIN
      IF @c_GetFrmArchDB = 'Y'
	  BEGIN
		  SELECT @c_StorerkeyOut = ORD.Storerkey
				,@c_GetExtPOKEY = ORD.ExternPOKEY
		  FROM ORDERS ORD WITH (NOLOCK)
		  WHERE ORD.Orderkey = @c_mbolordkey

      END
	  ELSE
	  BEGIN

	   SET @c_ExecStatements = ''
	   SELECT @c_ExecStatements = N'SELECT @c_StorerkeyOut = ORD.Storerkey ,@c_GetExtPOKEY = ORD.ExternPOKEY ' 
	   SELECT @c_ExecStatements = ISNULL(RTRIM(@c_ExecStatements),'') + ' '+' FROM '+ ISNULL(RTRIM(@c_arcdbname),'') + '.dbo.ORDERS ORD WITH (NOLOCK) '
							  + ' WHERE ORD.Orderkey = @c_mbolordkey '   
							 
							 
	   SET @c_ExecArguments = N'@c_arcdbname     NVARCHAR(50)' 
	                        +'  @c_mbolordkey    NVARCHAR(20)' 
                            +', @c_StorerkeyOut  NVARCHAR(20) OUTPUT' 
							+', @c_GetExtPOKEY   NVARCHAR(20) OUTPUT' 
                                    
  
   EXEC sp_ExecuteSql @c_ExecStatements   
                    , @c_ExecArguments  
                    , @c_arcdbname 
					, @c_mbolordkey
                    , @c_StorerkeyOut  OUTPUT 
					, @c_GetExtPOKEY   OUTPUT
	  END
   END

   SELECT @c_GetCustGrpName = ST.CustomerGroupName
   FROM STORER ST WITH (NOLOCK)
   WHERE ST.Storerkey = @c_StorerkeyOut

   UPDATE #TMP_MBLOAD
   SET Storerkey = @c_StorerkeyOut
      ,ExternPOKEY = @c_GetExtPOKEY
	  ,CustomerGroupName = @c_GetCustGrpName
   WHERE Orderkey = @c_mbolordkey
   and mbolkey = @c_mbolkey
   and isnull(Storerkey,'') = ''

   FETCH NEXT FROM CUR_RESULT INTO @c_mbolordkey,@c_chkstorerkey,@c_GetFrmArchDB 
   END

   SET @c_Storerkey = ''
   SET @c_RetriveArchDB = 'N'
   SELECT top 1 @c_Storerkey = Storerkey
   FROM #TMP_MBLOAD

   SELECT @c_RetriveArchDB = CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END
   FROM Codelkup CLR (NOLOCK)
   WHERE CLR.Storerkey = @c_Storerkey
   AND CLR.Code = 'RETRIVEARCHIVEDB'
   AND CLR.Listname = 'REPORTCFG'
   AND CLR.Long = 'r_dw_dmanifest_sum06' AND ISNULL(CLR.Short,'') <> 'N'

   --select @c_RetriveArchDB '@c_RetriveArchDB',@c_Storerkey '@c_Storerkey'

   IF @c_RetriveArchDB = 'N'
   BEGIN
     DELETE #TMP_MBLOAD
     WHERE FromArchDB = 'Y'
   END
    
    SELECT TMB.mbolkey,  
           vessel = TMB.vessel,   
           TMB.carrierkey,  
           TMB.loadkey,   
           TMB.orderkey,  
           TMB.externorderkey,  
           TMB.description,  
           TMB.deliverydate,  
           totalqty = 0,  
           totalorders = 0,  
           totalcust = 0,  
           TMB.Departuredate,   
           totalwgt = 99999999.99, 
           totalcarton = 0,       
           totaleach = 0,    
           TMB.totalcartons, 
           TMB.StorerKey,     
           TMB.CarrierAgent,    
           TMB.PlaceOfDelivery, 
           TMB.PlaceOfDischarge,
           TMB.OtherReference,  
           TMB.DriverName,      
           TMB.TransMethod,     
           TMB.PlaceOfLoading,  
           TMB.Remarks,         
           TMB.Descr,  
           TMB.CustomerGroupName, 
           TMB.EditWho,
           TMB.ShowField, --= ISNULL(CL.SHORT,'N'),        --WL01
           ProductEngine = CONVERT(NVARCHAR(100),''),      --WL01
           ExternPOKey = TMB.ExternPOKey,                  --WL01
		   TMB.FromArchDB,
		   PrintFlag = 'N'
    INTO #RESULT
	FROM #TMP_MBLOAD TMB
    --FROM MBOL (NOLOCK) 
    --INNER JOIN MBOLDETAIL (NOLOCK)  
    --      ON MBOL.mbolkey = MBOLDETAIL.mbolkey  
    --INNER JOIN ORDERS (NOLOCK) 
    --      ON MBOL.MbolKey = ORDERS.MBOLKey AND   
    --         MBOLDETAIL.OrderKey = ORDERS.OrderKey
    --INNER JOIN FACILITY (NOLOCK) ON MBOL.Facility = FACILITY.Facility 
    --INNER JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey 
    --LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'ShowField'                                   --WL01
    --                              AND CL.Long = 'r_dw_dmanifest_sum06' AND CL.STORERKEY = ORDERS.Storerkey                  --WL01
    WHERE TMB.mbolkey = @c_mbolkey  
    
	SET @n_totalorders = 0
	SET @n_totalcust = 0

	IF @c_RetriveArchDB = 'N'   --CS01 Start
	BEGIN
      SELECT @n_totalorders = COUNT(*), @n_totalcust = COUNT(DISTINCT description)  
      FROM MBOLDETAIL (NOLOCK)  
      WHERE mbolkey = @c_mbolkey  

	UPDATE #RESULT  
    SET totalorders = @n_totalorders,  
        totalcust = @n_totalcust  
    WHERE mbolkey = @c_mbolkey  

    END
	ELSE
	BEGIN
	   IF EXISTS (SELECT 1 FROM MBOLDETAIL (NOLOCK) WHERE mbolkey = @c_mbolkey)
	   BEGIN
	    SELECT @n_totalorders = COUNT(*), @n_totalcust = COUNT(DISTINCT description)  
        FROM MBOLDETAIL (NOLOCK)  
        WHERE mbolkey = @c_mbolkey 
	   END
	   ELSE
	   BEGIN
	     SET @c_ExecStatements = ''
	     SELECT @c_ExecStatements = N'SELECT @n_totalorders = COUNT(*), @n_totalcust = COUNT(DISTINCT description)  ' 
	     SELECT @c_ExecStatements = ISNULL(RTRIM(@c_ExecStatements),'') + ' '+' FROM '+ ISNULL(RTRIM(@c_arcdbname),'') + '.dbo.MBOLDETAIL WITH (NOLOCK) '
							  + ' WHERE mbolkey = @c_mbolkey '   
							 
							 
	   SET @c_ExecArguments = N'@c_arcdbname     NVARCHAR(50)' 
	                        +', @c_mbolkey       NVARCHAR(20)' 
                            +', @n_totalorders   INT OUTPUT' 
							+', @n_totalcust     INT OUTPUT' 
                                    
  
   EXEC sp_ExecuteSql @c_ExecStatements   
                    , @c_ExecArguments  
                    , @c_arcdbname 
					, @c_mbolkey
                    , @n_totalorders   OUTPUT 
					, @n_totalcust    OUTPUT


	   END

		UPDATE #RESULT  
		SET totalorders = @n_totalorders,  
			totalcust = @n_totalcust,
			PrintFlag = CASE WHEN FromArchDB = 'Y' THEN 'Y' ELSE PrintFlag END 
		WHERE mbolkey = @c_mbolkey 

    END  --CS01 END    
      
    DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY  
      FOR SELECT orderkey FROM #RESULT
        
    OPEN cur_1  
    FETCH NEXT FROM cur_1 INTO @c_orderkey  
    WHILE (@@fetch_status <> -1)  
    BEGIN  
       SELECT @n_totalqty = ISNULL(SUM(qty), 0)  
       FROM PICKDETAIL (NOLOCK)  
       WHERE orderkey = @c_orderkey  

       --WL01 START
       SELECT TOP 1 @c_BUSR7 = BUSR7 FROM SKU (NOLOCK)
       JOIN ORDERDETAIL (NOLOCK) ON SKU.SKU = ORDERDETAIL.SKU AND SKU.STORERKEY = ORDERDETAIL.STORERKEY
       WHERE ORDERDETAIL.ORDERKEY = @c_Orderkey

       SELECT @c_ProductEngine = ISNULL(CL2.description,'')
       FROM CODELKUP CL2 (NOLOCK) WHERE CL2.LISTNAME = 'NIKEPH001'
       AND CL2.CODE = @c_BUSR7 AND CL2.STORERKEY = (SELECT TOP 1 STORERKEY FROM ORDERS (NOLOCK) WHERE ORDERKEY = @c_Orderkey)
       --WL01 END

       UPDATE #RESULT  
       SET totalqty          = @n_totalqty
           ,ProductEngine    = ISNULL(@c_ProductEngine,'')            --WL01
       WHERE mbolkey = @c_mbolkey  
       AND orderkey = @c_orderkey
         
       FETCH NEXT FROM cur_1 INTO @c_orderkey  
    END  
    CLOSE cur_1  
    DEALLOCATE cur_1  
   
   --select * from #TMP_MBLOAD

    SELECT #TMP_MBLOAD.Mbolkey,  
           #TMP_MBLOAD.Orderkey,     
           totwgt = ISNULL(SUM(PICKDETAIL.Qty),0) * SKU.stdgrosswgt,  
           totcs = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) / PACK.CaseCnt ELSE 0 END,  
           totea = CASE WHEN PACK.CaseCnt > 0 THEN ISNULL(SUM(PICKDETAIL.Qty),0) % CAST (PACK.CaseCnt AS Int) ELSE 0 END      
    INTO #TEMPCALC  
    FROM PICKDETAIL (NOLOCK)   --CS01 Start
	JOIN SKU (NOLOCK) ON PICKDETAIL.sku = SKU.sku
	                  AND PICKDETAIL.Storerkey = SKU.Storerkey 
	JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey 
	JOIN #TMP_MBLOAD ON PICKDETAIL.Orderkey = #TMP_MBLOAD.Orderkey --ORDERS (NOLOCK)     
    WHERE  #TMP_MBLOAD.Mbolkey = @c_mbolkey  
    GROUP BY #TMP_MBLOAD.Mbolkey, #TMP_MBLOAD.Orderkey, PACK.CaseCnt, SKU.stdgrosswgt  
    
    SELECT Mbolkey, Orderkey, totwgt = SUM(totwgt), totcs = SUM(totcs), totea = SUM(totea)  
    INTO   #TEMPTOTAL   
    FROM   #TEMPCALC  
    GROUP BY Mbolkey, Orderkey  
      
    UPDATE #RESULT  
    SET totalwgt = t.totwgt,  
        totalcarton = t.totcs,  
        totaleach = t.totea 
    FROM  #TEMPTOTAL t   
    WHERE #RESULT.mbolkey = t.Mbolkey  
    AND   #RESULT.Orderkey = t.Orderkey  

    SELECT *  
    FROM #RESULT  
    ORDER BY loadkey, orderkey   
    
    DROP TABLE #RESULT  
    DROP TABLE #TEMPCALC  
    DROP TABLE #TEMPTOTAL  
 END 
 
 QUIT: 

GO