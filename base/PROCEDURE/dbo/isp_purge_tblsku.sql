SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure isp_Purge_TBLSku : 
--

CREATE PROC [dbo].[isp_Purge_TBLSku]
AS
BEGIN
	DECLARE @n_RowId		int
		, @n_continue 		int
	        , @n_starttcnt		int		-- Holds the current transaction count  
		, @b_debug		int
		, @n_counter		int
		, @c_ExecStatements  	nvarchar(4000)
                , @c_sku                NVARCHAR(20)
                , @c_storerkey          NVARCHAR(15)
                , @b_Success	        int 
                , @n_err		int 
                , @c_errmsg	        NVARCHAR(250)

	SET NOCOUNT ON

        SELECT @n_starttcnt = @@TRANCOUNT 
        
        CREATE TABLE TMPTBLSKU ( Sku NVARCHAR(20) NULL)
        CREATE TABLE TMPTBLSKU2 ( Sku NVARCHAR(20) NULL)

        SELECT @b_debug = 0
	SELECT @b_success = 0
	SELECT @n_continue = 1

        -- get all sku which has transaction
        SELECT Storerkey, Sku INTO #temp_itrn FROM ITRN (nolock) 
        WHERE Storerkey in ('TBLMY', 'TBLM1')

        -- get all sku which exist in lotxlocxid
        SELECT Storerkey, Sku INTO #temp_lotxlocxid FROM LotxLocxID (nolock) 
        WHERE Storerkey in ('TBLMY', 'TBLM1')

        -- get all sku which exist in archive..Itrn 
        SELECT Storerkey, Sku INTO #temp_archiveitrn FROM Archive..ITRN (nolock) 
        WHERE Storerkey in ('TBLMY', 'TBLM1')
          AND adddate >= '01-feb-2005'

         
        IF @b_debug = 1 
        BEGIN
          SELECT Count(*) FROM #temp_itrn (nolock)
          SELECT Count(*) FROM #temp_lotxlocxid (nolock)
          SELECT Count(*) FROM #temp_archiveitrn (nolock)        
        END

        -- Insert all skus to TMPTBLSKU
        INSERT INTO TMPTBLSKU 
        SELECT DISTINCT Sku, Storerkey FROM #temp_itrn (Nolock) 

        INSERT INTO TMPTBLSKU 
        SELECT DISTINCT Sku, Storerkey FROM #temp_lotxlocxid (Nolock) 

        INSERT INTO TMPTBLSKU 
        SELECT DISTINCT Sku, Storerkey FROM #temp_archiveitrn (Nolock)    

        -- Insert all filtered sku to TMPTBLSKU2 
        INSERT INTO TMPTBLSKU2 
        SELECT DISTINCT Sku, Storerkey FROM TMPTBLSKU (Nolock)


        Drop Table #temp_itrn
        Drop Table #temp_lotxlocxid
        Drop Table #temp_archiveitrn
        Drop Table TMPTBLSKU
       
        -- Start Looping Sku table 
 	SELECT @c_sku = ''	
        SELECT @n_counter = 0
        SELECT @n_RowId = 0

 
	WHILE (@n_continue=1)	
	BEGIN

                SELECT @c_sku = MIN(Sku)
		  FROM Sku (NOLOCK)
		 WHERE Sku > @c_sku
                   AND Storerkey in ('TBLMY', 'TBLM1')
               
                SELECT @c_storerkey = Storerkey
                  FROM Sku (NOLOCK)
                 WHERE Sku = @c_sku  


              IF @b_debug = 1
              BEGIN
               SELECT 'Sku'
               SELECT @c_sku    
               SELECT 'Storerkey'
               SELECT @c_storerkey              
              END

	      IF @b_debug = 1 SELECT 'Started Get sku...'

		-- Sku Checking
		IF NOT EXISTS (SELECT 1 FROM TMPTBLSKU2 (NOLOCK) WHERE Sku = dbo.fnc_RTRIM(@c_sku) and Storerkey = dbo.fnc_RTRIM(@c_storerkey) )
		BEGIN
                  
                  BEGIN TRAN
                  
                  SELECT @c_ExecStatements = ''	

		  SELECT @c_ExecStatements = N'INSERT INTO DTSITF..TBLSKU (StorerKey, Sku, DESCR, SUSR1, SUSR2, SUSR3, SUSR4, SUSR5, '
                                             + 'MANUFACTURERSKU, RETAILSKU, ALTSKU, PACKKey, STDGROSSWGT, '
                                       	     + 'STDNETWGT, STDCUBE, TARE, CLASS, ACTIVE, SKUGROUP, Tariffkey, '
	                                     + 'BUSR1, BUSR2, BUSR3, BUSR4, BUSR5, LOTTABLE01LABEL, LOTTABLE02LABEL, '
 	                                     + 'LOTTABLE03LABEL, LOTTABLE04LABEL, LOTTABLE05LABEL, NOTES1, NOTES2, '
 	                                     + 'PickCode, StrategyKey, CartonGroup, PutCode, PutawayLoc, PutawayZone, '
 	                                     + 'InnerPack, Cube, GrossWgt, NetWgt, ABC, CycleCountFrequency, LastCycleCount, '
     	                                     + 'ReorderPoint, ReorderQty, StdOrderCost, CarryCost, Price, Cost, ReceiptHoldCode, '
 	                                     + 'ReceiptInspectionLoc, OnReceiptCopyPackkey, TrafficCop, ArchiveCop, IOFlag, '
	                                     + 'TareWeight, LotxIdDetailOtherlabel1, LotxIdDetailOtherlabel2, LotxIdDetailOtherlabel3, '
	                                     + 'AvgCaseWeight, TolerancePct, SkuStatus, Length, Width, Height, weight, itemclass, '
	                                     + 'ShelfLife, Facility, BUSR6, BUSR7, BUSR8, BUSR9, BUSR10, ReturnLoc, ReceiptLoc, '
	                                     + 'archiveqty ) '
                                             + 'SELECT StorerKey, Sku, DESCR, SUSR1, SUSR2, SUSR3, SUSR4, SUSR5, '
                                             + 'MANUFACTURERSKU, RETAILSKU, ALTSKU, PACKKey, STDGROSSWGT, '
                                       	     + 'STDNETWGT, STDCUBE, TARE, CLASS, ACTIVE, SKUGROUP, Tariffkey, '
	                                     + 'BUSR1, BUSR2, BUSR3, BUSR4, BUSR5, LOTTABLE01LABEL, LOTTABLE02LABEL, '
 	                                     + 'LOTTABLE03LABEL, LOTTABLE04LABEL, LOTTABLE05LABEL, NOTES1, NOTES2, '
 	                                     + 'PickCode, StrategyKey, CartonGroup, PutCode, PutawayLoc, PutawayZone, '
 	                                     + 'InnerPack, Cube, GrossWgt, NetWgt, ABC, CycleCountFrequency, LastCycleCount, '
     	                                     + 'ReorderPoint, ReorderQty, StdOrderCost, CarryCost, Price, Cost, ReceiptHoldCode, '
 	                                     + 'ReceiptInspectionLoc, OnReceiptCopyPackkey, TrafficCop, ArchiveCop, IOFlag, '
	                                     + 'TareWeight, LotxIdDetailOtherlabel1, LotxIdDetailOtherlabel2, LotxIdDetailOtherlabel3, '
	                                     + 'AvgCaseWeight, TolerancePct, SkuStatus, Length, Width, Height, weight, itemclass, '
	                                     + 'ShelfLife, Facility, BUSR6, BUSR7, BUSR8, BUSR9, BUSR10, ReturnLoc, ReceiptLoc, '
	                                     + 'archiveqty  ' 
                                             + 'FROM Sku (NOLOCK) '
                                             + 'WHERE Sku = N''' + dbo.fnc_RTRIM(@c_sku) + ''' '
                                             + 'AND Storerkey = N''' + dbo.fnc_RTRIM(@c_storerkey) + ''' '

                                  EXEC sp_executesql @c_ExecStatements
                         
		           IF @@ERROR = 0
		           BEGIN 
			      IF @b_debug = 1
			      BEGIN
			         SELECT 'Insert Into TBLSKU table is Done !'
			      END
                           
                              DELETE FROM SKU 
                              WHERE Sku = dbo.fnc_RTRIM(@c_sku) 
                                AND Storerkey = dbo.fnc_RTRIM(@c_storerkey)
	               
		              COMMIT TRAN
		          END
		          ELSE
		          BEGIN
		           ROLLBACK TRAN
		           SELECT @n_continue = 3
			   SELECT @n_err = 65002
	                   SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert records failed (isp_Purge_TBLSku)'  
		         END

           END -- Not Exists
       END -- While 1=1 


	-- Drop Temp Table
	DROP TABLE TMPTBLSKU2 


   /* #INCLUDE <SPTPA01_2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
	ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
	 BEGIN  
          COMMIT TRAN  
         END  
      END  

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_Purge_TBLSku'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
	END  
END

GO