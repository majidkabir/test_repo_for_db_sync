SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*********************************************************************************************************************/  
/* Stored Proc:																										 */
/* Creation Date: 14-Aug-2023                     																	 */                     
/* Written by: Tyrion                                   															 */               
/* Copy from [BI].[nsp_IKEA_PreAllocate_Qty_Report]                                                      	     	 */             
/* Purpose:  CN IKEA Pre-Allocate Report_store																		 */  
/* Version: Tyrion     1.0         Created																	     	 */  
/* Version: Tyrion     1.1         Deployed IN CNWMS https://jiralfl.atlassian.net/browse/WMS-23432					 */ 
/*********************************************************************************************************************/  

CREATE     PROC [BI].[nsp_IKEA_PreAllocate_Qty_Report_store]
    @Facility NVARCHAR(10),
	@fromarea NVARCHAR(10) ,           
	@toarea NVARCHAR(10),
    @startdate DATETIME,  
    @enddate DATETIME     
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_NULLS OFF;
    SET QUOTED_IDENTIFIER OFF;
    SET CONCAT_NULL_YIELDS_NULL OFF;

    DECLARE @n_StorerKey NVARCHAR(10),
            @n_Status NVARCHAR(10),
            @n_Qty INT,
            @n_QtyReplen INT,
            @n_QtyPickLoc INT,
            @n_MaxRowID INT,
            @n_QtyCandi INT,
            @n_QtyUnReplen INT,
            @n_PickLoc NVARCHAR(10),
			@n_PickLocarea NVARCHAR(10),   
            @n_BulkQty INT;

    DECLARE @i INT;

    DECLARE @c_SKU NVARCHAR(20),
            @c_QtyOrdered INT,
            @c_QtyReplen INT,
            @c_QryUnReplen INT;

	DECLARE @storefilter nvarchar(max),
			@parafilter nvarchar(max),
			@adddatefilter nvarchar(max),
			@groupfilter  nvarchar(max),
			@main nvarchar(max),
			@ToAreaCvt NVARCHAR(10),
			@FromAreaCvt NVARCHAR(10);

    SET @n_StorerKey = 'IKEA';
    SET @n_Status = '0';
    SET @n_Qty = 0;
    SET @n_QtyReplen = 0;
    SET @n_QtyPickLoc = 0;
    SET @n_MaxRowID = 0;
    SET @n_QtyCandi = 0;
	SET @n_PickLocarea = '';       
    SET @n_QtyUnReplen = 0;
    SET @n_PickLoc = '';
    SET @n_BulkQty = 0;

    SET @Facility = UPPER(@Facility);
	if isnull(@startdate,'') = ''
	set @startdate = getdate();
	if isnull(@enddate,'') = ''
	set @enddate = getdate();

	if isnull(@toarea,'') = 'TM'
		set @storefilter = N' = ''618'' '
	if isnull(@toarea,'') = 'GW'
		set @storefilter = N' <> ''618'' '
	else if isnull(@toarea,'') = ''
		set @storefilter = N'= isnull(oi.storename,'''') '
---set @ToAreaCvt accroding to @toarea
	if isnull(@toarea,'') = 'TM'
		set @ToAreaCvt = N'SN'
	if isnull(@toarea,'') = 'GW'
		set @ToAreaCvt = N'JD'
---set @FromAreaCvt accroding to @FromArea
	if isnull(@fromarea,'') = 'TM'
		set @FromAreaCvt = N'SN'
	if isnull(@toarea,'') = 'GW'
		set @FromAreaCvt = N'JD'

IF OBJECT_ID('tempdb..#Open_Qty','u') IS NOT NULL  DROP TABLE #Open_Qty;
    CREATE TABLE #Open_Qty
    (
        SKU NVARCHAR(20),
        QtyOrdered INT,
        QtyReplen INT
    );

IF OBJECT_ID('tempdb..#Temp_BulkInv','u') IS NOT NULL  DROP TABLE #Temp_BulkInv;
    CREATE TABLE #Temp_BulkInv
    (
        RowID INT,
        SKU NVARCHAR(20),
        ID NVARCHAR(30),
        CaseCnt INT,
        Qty INT,
        LOC NVARCHAR(10),
        LogicalLOC NVARCHAR(10),
        Lottable04 NVARCHAR(10),
        susr3 NVARCHAR(18),
		HOSTWHCODE  NVARCHAR(18)
    );

 IF OBJECT_ID('tempdb..#Temp_Result','u') IS NOT NULL  DROP TABLE #Temp_Result;
    CREATE TABLE #Temp_Result
    (
        Facility NVARCHAR(10),
        SKU NVARCHAR(20),
        CaseCnt INT,
        ID NVARCHAR(30),
        QtyReplen INT,
        CaseReplen INT,
        BulkLoc NVARCHAR(10),
        BulkQty INT,
        PickLoc NVARCHAR(10),
        susr3 NVARCHAR(18),
		  fromarea NVARCHAR(18),  
		  toarea NVARCHAR(18)    
    );
	set @parafilter = N' where  o.storerkey =' + ''''+@n_StorerKey+'''' + N'and o.facility =' + ''''+ @Facility + '''' +  N'and o.[Status] = '+ '''' + @n_Status  + ''''
		print @parafilter;
	set @adddatefilter =  N' and o.AddDate >= ' + ''''+convert(varchar(50),@startdate,20)+'''' +  N' and o.AddDate <= ' + ''''+convert(varchar(50),@enddate,20)+''''
		print @adddatefilter
	set @storefilter = N'and isnull(oi.storename,'''')' +  @storefilter
		print @storefilter  
	set @groupfilter = N'GROUP BY od.Sku'
		print @groupfilter  

IF @toarea =''                           
	  BEGIN
		INSERT INTO #Open_Qty                     
		(
			SKU,
			QtyOrdered,
			QtyReplen
		)
		SELECT od.Sku,
			   SUM(od.OriginalQty),
			   0
		FROM BI.V_ORDERS o WITH (NOLOCK)
		JOIN BI.V_ORDERDETAIL od WITH (NOLOCK) ON od.OrderKey = o.OrderKey
		WHERE o.StorerKey = @n_StorerKey
		AND o.[Status] = @n_Status
		AND o.Facility = @Facility
		AND o.AddDate >= @startdate   
		AND o.AddDate < @enddate     
		GROUP BY od.Sku;
	  END
ELSE
    --SELECT * FROM #Open_Qty
	set @main = N'   
			INSERT INTO #Open_Qty  
			(  
				SKU,  
				QtyOrdered,  
				QtyReplen  
			)  
			SELECT od.Sku,  
				   SUM(od.OriginalQty),  
				   0  
			FROM		BI.V_ORDERS o WITH (NOLOCK)  
			JOIN		BI.V_ORDERDETAIL od WITH (NOLOCK)  ON od.OrderKey = o.OrderKey             
			left join   BI.V_OrderInfo oi WITH (NOLOCK) on o.OrderKey = oi.OrderKey'
			+ @parafilter 
			+ @adddatefilter 
			+ @storefilter
			+ @groupfilter
			print @main
		 exec sp_executesql @main 
DECLARE my_cur CURSOR FAST_FORWARD READ_ONLY FOR
    SELECT SKU,
           QtyOrdered
    FROM #Open_Qty;
    OPEN my_cur;
    FETCH NEXT FROM my_cur
    INTO @c_SKU,
         @c_QtyOrdered;
    WHILE @@FETCH_STATUS <> -1
    BEGIN

        SET @n_QtyPickLoc = 0;

        SELECT @n_QtyPickLoc = ISNULL(SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked), 0)
        FROM BI.V_LOTxLOCxID lli WITH (NOLOCK)
        JOIN BI.V_LOC l WITH (NOLOCK) ON l.Loc = lli.Loc
        WHERE l.Facility = @Facility
              AND l.LocationType = 'PICK'
              AND l.HOSTWHCODE = CASE
                                     WHEN @toarea = '' THEN
                                         l.HOSTWHCODE
                                     ELSE
                                         @ToAreaCvt
                                 END  
              AND lli.StorerKey = @n_StorerKey
              AND lli.Sku = @c_SKU;

        UPDATE #Open_Qty
        SET QtyReplen = @c_QtyOrdered - @n_QtyPickLoc
        WHERE SKU = @c_SKU;

        FETCH NEXT FROM my_cur
        INTO @c_SKU,
             @c_QtyOrdered;
    END;
    CLOSE my_cur;
    DEALLOCATE my_cur;

    --SELECT * FROM #Open_Qty WHERE QtyReplen > 0

   IF @fromarea <>''                           
            BEGIN
            INSERT INTO #Temp_BulkInv
             (
                 RowID,
                 SKU,
                 ID,
                 CaseCnt,
                 Qty,
                 LOC,
                 LogicalLOC,
                 Lottable04,
                 susr3,
                 HOSTWHCODE    
             )
                   SELECT ROW_NUMBER() OVER (PARTITION BY lli.Sku ORDER BY lot.Lottable04),
                          lli.Sku,
                          lli.Id,
                          lot.Lottable03,
                          SUM(lli.Qty),
                          lli.Loc,
                          l.LogicalLocation,
                          lot.Lottable04,
                          sku.SUSR3,
                		   l.HOSTWHCODE    
                   FROM #Open_Qty #O WITH (NOLOCK)
                   JOIN BI.V_LOTxLOCxID lli WITH (NOLOCK) ON #O.SKU = lli.Sku AND lli.StorerKey = @n_StorerKey
                   JOIN BI.V_LOC l WITH (NOLOCK) ON lli.Loc = l.Loc AND l.Facility = @Facility
                   JOIN BI.V_LOTATTRIBUTE lot WITH (NOLOCK) ON lot.Lot = lli.Lot
                   JOIN BI.V_SKU sku (NOLOCK) ON sku.StorerKey = @n_StorerKey AND sku.Sku = lli.Sku
                   WHERE #O.QtyReplen > 0
                         AND l.LocationType = 'pick'
                         AND l.LocationFlag = 'none'
                         AND l.LocationCategory = 'other'
                         AND lli.Qty > 0
						       AND  l.HOSTWHCODE = @fromarea  
                		  
                   GROUP BY lli.Sku,
                            lli.Id,
                            lot.Lottable03,
                            lli.Loc,
                            l.LogicalLocation,
                            lot.Lottable04,
                            sku.SUSR3,
                			 l.HOSTWHCODE;
                
                           END
                
            ELSE
            BEGIN
                 INSERT INTO #Temp_BulkInv                               
                 (
                     RowID,
                     SKU,
                     ID,
                     CaseCnt,
                     Qty,
                     LOC,
                     LogicalLOC,
                     Lottable04,
                     susr3,
              		HOSTWHCODE    
                 )
                 SELECT ROW_NUMBER() OVER (PARTITION BY lli.Sku ORDER BY lot.Lottable04),
                        lli.Sku,
                        lli.Id,
                        lot.Lottable03,
                        SUM(lli.Qty),
                        lli.Loc,
                        l.LogicalLocation,
                        lot.Lottable04,
                        sku.SUSR3,
              		   l.HOSTWHCODE    
                 FROM #Open_Qty #O WITH (NOLOCK)
                     JOIN BI.V_LOTxLOCxID lli WITH (NOLOCK) ON #O.SKU = lli.Sku AND lli.StorerKey = @n_StorerKey
                     JOIN BI.V_LOC l WITH (NOLOCK)ON lli.Loc = l.Loc AND l.Facility = @Facility
                     JOIN BI.V_LOTATTRIBUTE lot WITH (NOLOCK)ON lot.Lot = lli.Lot
                     JOIN BI.V_SKU sku (NOLOCK) ON sku.StorerKey = @n_StorerKey AND sku.Sku = lli.Sku
                 WHERE #O.QtyReplen > 0
                       AND l.LocationType = 'other'
                       AND l.LocationFlag = 'none'
                       AND l.LocationCategory = 'other'
                       AND lli.Qty > 0
              		  
                 GROUP BY lli.Sku,
                          lli.Id,
                          lot.Lottable03,
                          lli.Loc,
                          l.LogicalLocation,
                          lot.Lottable04,
                          sku.SUSR3,
              			 l.HOSTWHCODE;
                 END;                                         

    --SELECT * FROM #Temp_BulkInv

    DECLARE rpl_cur CURSOR FAST_FORWARD READ_ONLY FOR
    SELECT SKU,
           QtyReplen
    FROM #Open_Qty
    WHERE QtyReplen > 0;

    OPEN rpl_cur;
    FETCH NEXT FROM rpl_cur
    INTO @c_SKU,
         @c_QtyReplen;
    WHILE @@FETCH_STATUS <> -1
    BEGIN

        SET @i = 1;
        SET @n_QtyUnReplen = 0;
        SET @n_MaxRowID = 0;

        SELECT @n_MaxRowID = MAX(RowID)
        FROM #Temp_BulkInv
        WHERE SKU = @c_SKU;


        SELECT @n_QtyUnReplen = @c_QtyReplen;

      WHILE @i <= @n_MaxRowID AND @n_QtyUnReplen > 0
       BEGIN

            SELECT TOP 1
                @n_QtyCandi = Qty
            FROM #Temp_BulkInv
            WHERE SKU = @c_SKU
                  AND RowID = @i
            ORDER BY RowID,
                     LogicalLOC,
                     LOC;

		IF @toarea  = ''            
			BEGIN
            SELECT TOP 1                         
                @n_PickLoc = lli.Loc,
				@n_PickLocarea = l.HOSTWHCODE                     
            FROM BI.V_LOTxLOCxID lli WITH (NOLOCK)
             JOIN BI.V_LOC l WITH (NOLOCK) ON l.Loc = lli.Loc
            WHERE l.Facility = @Facility
                  AND l.LocationType = 'PICK'
                  AND lli.StorerKey = 'IKEA'
                  AND lli.Sku = @c_SKU
            GROUP BY lli.Loc    ,l.HOSTWHCODE                      
            ORDER BY ISNULL(SUM(lli.Qty), 0),l.HOSTWHCODE DESC; ----recommend pick loc with biggest qty 
			END
		ELSE
			BEGIN
            SELECT TOP 1
                @n_PickLoc = lli.Loc,
				@n_PickLocarea = l.HOSTWHCODE                         
            FROM BI.V_LOTxLOCxID lli WITH (NOLOCK)
            JOIN BI.V_LOC l WITH (NOLOCK) ON l.Loc = lli.Loc
            WHERE l.Facility = @Facility
                  AND l.LocationType = 'PICK'
                  AND lli.StorerKey = 'IKEA'
                  AND lli.Sku = @c_SKU
				  AND l.HOSTWHCODE = @ToAreaCvt
            GROUP BY lli.Loc    ,l.HOSTWHCODE                       
            ORDER BY ISNULL(SUM(lli.Qty), 0),l.HOSTWHCODE DESC; ----recommend pick loc with biggest qty 
		END                          

            IF @n_QtyCandi > @c_QtyReplen
            BEGIN

                INSERT INTO #Temp_Result
                (
                    Facility,
                    SKU,
                    CaseCnt,
                    ID,
                    QtyReplen,
                    CaseReplen,
                    BulkLoc,
                    BulkQty,
                    PickLoc,
                    susr3,
					fromarea, 
					toarea     
                )
                SELECT @Facility,
                       SKU,
                       CaseCnt,
                       ID,
                       CEILING(@c_QtyReplen * 1.0 / CaseCnt) * CaseCnt,
                       CEILING(@c_QtyReplen * 1.0 / CaseCnt),
                       LOC,
                       @n_QtyCandi, --@n_BulkQty
                       @n_PickLoc,
                       susr3,
					   HOSTWHCODE, --@n_BulkQtyarea   
                       @n_PickLocarea             

                FROM #Temp_BulkInv
                WHERE SKU = @c_SKU
                      AND RowID = @i;

                --SET @i = @i + 999
                SET @n_QtyUnReplen = @n_QtyUnReplen - @n_QtyCandi;
                BREAK;

            END;

            ELSE
            BEGIN

                INSERT INTO #Temp_Result
                (
                    Facility,
                    SKU,
                    CaseCnt,
                    ID,
                    QtyReplen,
                    CaseReplen,
                    BulkLoc,
                    BulkQty,
                    PickLoc,
                    susr3,
					fromarea,
					toarea   
                )
                SELECT @Facility,
                       SKU,
                       CaseCnt,
                       ID,
                       CEILING(Qty * 1.0 / CaseCnt) * CaseCnt,
                       CEILING(Qty * 1.0 / CaseCnt),
                       LOC,
                       @n_QtyCandi, 
                       @n_PickLoc,
                       susr3 ,
					   HOSTWHCODE,
                       @n_PickLocarea          
                FROM #Temp_BulkInv
                WHERE SKU = @c_SKU
                      AND RowID = @i;

                SET @i = @i + 1;
                SET @n_QtyUnReplen = @n_QtyUnReplen - @n_QtyCandi;
            END;
        END;

        FETCH NEXT FROM rpl_cur
        INTO @c_SKU,
             @c_QtyReplen;
    END;
    CLOSE rpl_cur;
    DEALLOCATE rpl_cur;

    SELECT *
    FROM #Temp_Result
    ORDER BY BulkLoc,SKU;

END


GO