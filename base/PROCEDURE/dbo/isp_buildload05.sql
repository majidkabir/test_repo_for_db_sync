SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_BuildLoad05                                             */
/* Creation Date: 19-OCT-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15499 CN UA Build load                                  */
/*        :                                                             */
/* Called By:isp_Build_Loadplan                                         */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_BuildLoad05] 
            @c_Facility           NVARCHAR(5)
         ,  @c_Storerkey          NVARCHAR(15)
         ,  @c_ParmCode           NVARCHAR(10)
         ,  @c_ParmCodeCond       NVARCHAR(4000)
         ,  @c_Parm01             NVARCHAR(50) = '' -- PCS, CS
         ,  @c_Parm02             NVARCHAR(50) = ''
         ,  @c_Parm03             NVARCHAR(50) = ''
         ,  @c_Parm04             NVARCHAR(50) = ''
         ,  @c_Parm05             NVARCHAR(50) = ''
         ,  @dt_StartDate         DATETIME     = NULL  
         ,  @dt_EndDate           DATETIME     = NULL  
         ,  @n_NoOfOrderToRelease INT          = 0     
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @b_Success         INT 
         , @n_err             INT 
         , @c_errmsg          NVARCHAR(255)  
         , @c_SQL             NVARCHAR(MAX)
         , @c_SQLOrderBy      NVARCHAR(4000) 
         , @b_JoinPickDetail  BIT = 0 
         , @b_JoinLoc         BIT = 0           
         , @b_Debug           BIT
         
   DECLARE @c_Sku            NVARCHAR(20),
           @c_Loc            NVARCHAR(10), 
           @c_Lot            NVARCHAR(10), 
           @c_ID             NVARCHAR(18), 
           @n_QtyOrdered     INT,
           @n_UCCQty         INT,
           @c_Orderkey       NVARCHAR(10),
           @n_SkuSeq         INT,
           @n_Casecnt        INT,
           @b_JoinOrderInfo  BIT = 0,
           @n_cnt            INT = 0,
           @n_MaxOrders      INT = 0,
           @n_SkuLocMaxQty   INT = 0, 
           @n_QtyCnt         INT = 0,
           @n_FullCaseQty    INT = 0
            
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @b_Debug = 0
   IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NULL
   BEGIN
      CREATE TABLE #TMP_ORDERS
      (  RowNo       BIGINT   IDENTITY(1,1)  Primary Key 
      ,  Orderkey    NVARCHAR(10)   NULL
      )
      SET @b_Debug = 1
   END

   CREATE TABLE #TMP_ORDERSSKU
   (  RowNo          BIGINT   IDENTITY(1,1)  Primary Key 
   ,  Orderkey       NVARCHAR(10)   NULL 
   ,  Sku            NVARCHAR(20)   NULL
   ,  Loc            NVARCHAR(10)   NULL
   ,  SkuSeq         INT            NULL
   ,  CaseCnt        FLOAT          NULL
   ,  SkuQty         INT            NULL
   ,  SkuCaseCnt     FLOAT          NULL
   ,  SkuLocMaxQty   INT            NULL
   ,  Lot            NVARCHAR(10)   NULL  
   ,  ID             NVARCHAR(18)   NULL  
    )

    IF CHARINDEX('PICKDETAIL.', @c_ParmCodeCond) > 1
    BEGIN
      SET @b_JoinPickDetail = 1
    END

    IF CHARINDEX('LOC.', @c_ParmCodeCond) > 1
    BEGIN
      SET @b_JoinLoc = 1
    END
   
    IF CHARINDEX('ORDERINFO.', @c_ParmCodeCond) > 1
    BEGIN
      SET @b_JoinOrderInfo = 1
    END
            
    IF CHARINDEX('FROM', @c_ParmCodeCond) > 0
    BEGIN
       IF CHARINDEX('WHERE', @c_ParmCodeCond) > 0
       BEGIN
       	  SET @c_ParmCodeCond = ' AND ' + SUBSTRING(@c_ParmCodeCond, CHARINDEX('WHERE', @c_ParmCodeCond) + 5, LEN(@c_ParmCodeCond))
       END
    END

   SET @c_SQL = N' DECLARE CURSOR_BLORD CURSOR FAST_FORWARD READ_ONLY FOR ' 
              + 'SELECT ORDERS.Orderkey '
              + ', ORDERDETAIL.Sku' 
              + ', PICKDETAIL.Loc'                                                                 
              + CASE WHEN @c_Parm01 IN('UCC','UCCPCS') THEN ', SkuSeq = ROW_NUMBER() OVER ( PARTITION BY ORDERDETAIL.Sku, PICKDETAIL.Loc, PICKDETAIL.Lot, PICKDETAIL.Id'  
                     ELSE ', SkuSeq = ROW_NUMBER() OVER ( PARTITION BY ORDERDETAIL.Sku, PICKDETAIL.Loc' END +
              --+ ', SkuSeq = ROW_NUMBER() OVER ( PARTITION BY ORDERDETAIL.Sku, PICKDETAIL.Loc'      --(Wan02)  
              +                               ' ORDER BY ORDERS.Orderkey'
              +                                       ', ORDERDETAIL.Sku'
              +                                       ', PICKDETAIL.Loc'                            
              +                                       ', PICKDETAIL.Lot'                                           
              +                                       ', PICKDETAIL.ID'                                          
              +                               ' )' 
              + ', CaseCnt = ISNULL(PACK.CaseCnt,0.00)'
              + ', PICKDETAIL.Lot, PICKDETAIL.ID'  
              + ' FROM ORDERS WITH (NOLOCK)'
              + ' JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)'
              + ' JOIN SKU  WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)'
              +                         ' AND(ORDERDETAIL.Sku = SKU.Sku)'
              + ' JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)'
              + ' JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey=PICKDETAIL.Orderkey) AND (ORDERDETAIL.OrderLineNumber=PICKDETAIL.OrderLineNumber)'
              + CASE WHEN @b_JoinLoc = 1 
                     THEN ' LEFT JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc=LOC.Loc AND LOC.Facility = @c_Facility)' 
                     ELSE ''
                     END
              + ' LEFT JOIN LoadPlanDetail LD (NOLOCK) ON LD.OrderKey = ORDERS.OrderKey'  
              + CASE WHEN @b_JoinOrderInfo = 1 
                     THEN ' LEFT JOIN OrderInfo WITH(NOLOCK) ON OrderInfo.OrderKey = ORDERS.OrderKey'             
                     ELSE ''
                     END
              + ' WHERE ORDERS.Facility  = @c_Facility'
              + ' AND   ORDERS.Storerkey = @c_Storerkey'
              + ' AND   ORDERS.Status < ''9'''
              + ' AND  (ORDERS.Loadkey IS NULL OR ORDERS.Loadkey = '''')'
              + ' AND   ORDERS.OpenQty = 1'      
              + ' AND LD.LoadKey IS NULL'
              + ' AND ORDERS.SOStatus <> ''PENDING'' '  
              + ' AND NOT EXISTS (SELECT 1 FROM CODELKUP WITH (NOLOCK) '  
              + ' WHERE CODELKUP.Code = ORDERS.SOStatus ' 
              + ' AND CODELKUP.Listname = ''LBEXCSOSTS'' '
              + ' AND CODELKUP.Storerkey = ORDERS.Storerkey) '  
              + ' AND ((ORDERS.UserDefine08 = ''N'' AND ( ORDERS.UserDefine09 = '''' OR ORDERS.UserDefine09 is NULL) AND (ORDERS.Status < ''8'') ) OR '           
              + '      (ORDERS.UserDefine08 = ''Y'' AND ORDERS.UserDefine09 <> '''' AND (ORDERS.Status >= ''1'' AND ORDERS.Status < ''8'' ) ))  '   
              
                 
   IF @c_ParmCodeCond <> ''
   BEGIN
      SET @c_SQL =  @c_SQL + @c_ParmCodeCond
   END 

   BEGIN TRAN

   /*
   INSERT INTO #TMP_ORDERSSKU
         (  Orderkey
         ,  Sku
         ,  Loc                                                                   
         ,  SkuSeq
         ,  CaseCnt
         ,  Lot, ID   --NJOW01
         )
   */      
               
   EXEC sp_executesql @c_SQL
         , N'@c_Facility NVARCHAR(5), @c_Storerkey NVARCHAR(15),@dt_StartDate DATETIME, @dt_EndDate DATETIME'
         , @c_Facility
         , @c_Storerkey
         , @dt_StartDate
         , @dt_EndDate    
   
   OPEN CURSOR_BLORD
            
   FETCH NEXT FROM CURSOR_BLORD INTO @c_Orderkey, @c_Sku, @c_Loc, @n_SkuSeq, @n_Casecnt, @c_Lot, @c_ID         
              
   WHILE @@FETCH_STATUS = 0   
   BEGIN
      INSERT INTO #TMP_ORDERSSKU
         (  Orderkey
         ,  Sku
         ,  Loc             
         ,  SkuSeq
         ,  CaseCnt
         ,  Lot, ID   
         )
         VALUES 
         (  @c_Orderkey
         ,  @c_Sku
         ,  @c_Loc
         ,  @n_SkuSeq
         ,  @n_Casecnt
         ,  @c_Lot
         ,  @c_ID
         )
      FETCH NEXT FROM CURSOR_BLORD INTO @c_Orderkey, @c_Sku, @c_Loc, @n_SkuSeq, @n_Casecnt, @c_Lot, @c_ID         
   END         	
   CLOSE CURSOR_BLORD
   DEALLOCATE CURSOR_BLORD


   UPDATE #TMP_ORDERSSKU 
   SET SkuLocMaxQty =( SELECT ISNULL(MAX(SkuSeq),0)
                  FROM #TMP_ORDERSSKU SEL WHERE SEL.Sku = #TMP_ORDERSSKU.Sku  AND  SEL.Loc = #TMP_ORDERSSKU.Loc)

   UPDATE #TMP_ORDERSSKU 
      SET SkuQty = ( SELECT ISNULL(MAX(SkuSeq),0)
                     FROM #TMP_ORDERSSKU SEL WHERE SEL.Sku = #TMP_ORDERSSKU.Sku )

   SELECT TOP 1 @n_MaxOrders= CASE WHEN ISNUMERIC(Notes) = 1 THEN CAST(Notes AS INT) ELSE 0 END                            
   FROM Codelkup WITH (NOLOCK)                                                                                                                                 
   WHERE LISTNAME = @c_ParmCode                                                                                                                                 
   AND long = 'Max_Orders_Per_Load'
   
   IF ISNULL(@n_NoOfOrderToRelease,0) = 0
      SET @n_NoOfOrderToRelease = 999999
   
   IF @n_NoOfOrderToRelease > @n_MaxOrders AND ISNULL(@n_MaxOrders,0) > 0
      SET @n_NoOfOrderToRelease = @n_MaxOrders
   
   DECLARE CURSOR_LOCQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Sku, Loc, SkuLocMaxQty, Casecnt
      FROM #TMP_ORDERSSKU
      WHERE Casecnt > 0
      AND SkuLocMaxQty >= CaseCnt 
      GROUP BY Sku, Loc, SkuLocMaxQty, Casecnt
      ORDER BY SKU, Loc
      
   OPEN CURSOR_LOCQTY                                                                                                                                    
                                                                                                                                                            
   FETCH NEXT FROM CURSOR_LOCQTY INTO @c_Sku, @c_Loc, @n_SkuLocMaxQty, @n_CaseCnt      
   
   SET @n_QtyCnt = 0
   WHILE @@FETCH_STATUS <> -1 AND @n_NoOfOrderToRelease > @n_QtyCnt --AND @n_NoOfOrderToRelease >= @n_QtyCnt + @n_CaseCnt                                                                                                                           
   BEGIN  	  
   	  SET @n_FullCaseQty = FLOOR((@n_SkuLocMaxQty * 1.0) / @n_Casecnt) * @n_Casecnt  

 	  	WHILE @n_FullCaseQty + @n_QtyCnt > @n_NoOfOrderToRelease
 	  	BEGIN
 	  	   SET @n_FullCaseQty = @n_FullCaseQty - @n_CaseCnt
 	  	END
   	  
   	  IF @n_FullCaseQty > 0
   	  BEGIN
   	     UPDATE #TMP_ORDERSSKU 
   	     SET SkuCaseCnt = @n_FullCaseQty
   	     WHERE Sku = @c_Sku
   	     AND Loc = @c_Loc
   	     
         SET @n_QtyCnt = @n_QtyCnt + @n_FullCaseQty
      END	        	  
      
      FETCH NEXT FROM CURSOR_LOCQTY INTO @c_Sku, @c_Loc, @n_SkuLocMaxQty, @n_CaseCnt    
   END                 
   CLOSE CURSOR_LOCQTY
   DEALLOCATE CURSOR_LOCQTY          
      
   /* 
   UPDATE #TMP_ORDERSSKU 
      SET SkuCaseCnt = CASE WHEN #TMP_ORDERSSKU.CaseCnt = 0.00 
                            THEN 0.00 
                            ELSE
                              FLOOR((#TMP_ORDERSSKU.SkuLocMaxQty * 1.0) / #TMP_ORDERSSKU.CaseCnt ) * #TMP_ORDERSSKU.CaseCnt   
                            END      
   */                                
                         
   IF @c_Parm01 IN('UCC','UCCPCS')
   BEGIN   	   
       UPDATE #TMP_ORDERSSKU SET SkuCaseCnt = 0   	
      
   	   DECLARE CUR_SKULOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   	     SELECT Sku, Loc, Lot, Id, SUM(1) AS Qty
   	     FROM #TMP_ORDERSSKU 
         GROUP BY Sku, Loc, Lot, Id   	   
   	     ORDER BY Sku, Loc, Lot, Id
   	     
   	   OPEN CUR_SKULOC

       FETCH NEXT FROM CUR_SKULOC INTO @c_Sku, @c_Loc, @c_Lot, @c_ID, @n_QtyOrdered
       
       SET @n_cnt = 0   	   
       WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND NOT (@c_Parm01 = 'UCC' AND @n_cnt >= @n_NoOfOrderToRelease)
       BEGIN   	      	   
       	  IF @c_Parm01 = 'UCC'
       	  BEGIN
       	  	 IF @n_QtyOrdered > (@n_NoOfOrderToRelease - @n_cnt)
       	  	 BEGIN
       	  	 	  IF NOT EXISTS(SELECT 1 
                              FROM UCC WITH (NOLOCK)
                              WHERE StorerKey = @c_StorerKey
                              AND SKU = @c_SKU
                              AND Lot = @c_Lot
                              AND Loc = @c_Loc
                              AND ID = @c_Id
                              AND Status < '3'
                              GROUP BY Qty
                              HAVING SUM(Qty) >= @n_QtyOrdered) --if only build some orders from the lot,loc,id and some remain orders get from different ucc size, do not build and skip for next build. 
                BEGIN                     	  	 	                
       	  	       SET @n_QtyOrdered = 0    	 
       	  	    END
       	  	    ELSE
       	  	       SET @n_QtyOrdered = (@n_NoOfOrderToRelease - @n_cnt)    	  	        	  	       
       	  	 END   
       	  END
       	
          DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
             SELECT Qty
             FROM UCC WITH (NOLOCK)
             WHERE StorerKey = @c_StorerKey
             AND SKU = @c_SKU
             AND Lot = @c_Lot
             AND Loc = @c_Loc
             AND ID = @c_Id
             AND Status < '3'
             AND Qty <= @n_QtyOrdered
             ORDER BY Qty, UccNo
             --ORDER BY EditDate DESC, CASE WHEN @n_QtyOrdered % Qty = 0 THEN 1 ELSE 2 END, Qty    	
          
          OPEN CUR_UCC
            
          FETCH NEXT FROM CUR_UCC INTO @n_UCCQty         
               
          WHILE @@FETCH_STATUS = 0 AND @n_QtyOrdered > 0 AND @n_continue IN(1,2)
          BEGIN         	
          	 IF @n_UCCQty <= @n_QtyOrdered
          	 BEGIN
          	 	  UPDATE #TMP_ORDERSSKU 
          	 	  SET SkuCaseCnt = SkuCaseCnt + @n_UCCQty
          	 	  WHERE Sku = @C_Sku
          	 	  AND Loc = @c_Loc
          	 	  AND Lot = @C_Lot
          	 	  AND Id = @c_Id

                IF @c_Parm01 = 'UCC'
                   SET @n_cnt = @n_cnt + @n_UCCQty
                
                SET @n_QtyOrdered = @n_QtyOrdered - @n_UCCQty
          	 END
          	 ELSE
          	 BEGIN
          	 	  SET @n_QtyOrdered = 0
          	 END
          	
             FETCH NEXT FROM CUR_UCC INTO @n_UCCQty                   	
          END
          CLOSE CUR_UCC
          DEALLOCATE CUR_UCC      
          
          FETCH NEXT FROM CUR_SKULOC INTO  @c_Sku, @c_Loc, @c_Lot, @c_ID, @n_QtyOrdered
       END
       CLOSE CUR_SKULOC
       DEALLOCATE CUR_SKULOC
       
       IF @c_Parm01 = 'UCC'
       BEGIN
          INSERT INTO #TMP_ORDERS 
             (  Orderkey    )  
          SELECT Orderkey   
          FROM #TMP_ORDERSSKU
          WHERE SkuSeq <= SkuCaseCnt
       END
       
      IF @c_Parm01 = 'UCCPCS'
      BEGIN
         DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT Orderkey   
         FROM #TMP_ORDERSSKU
         WHERE (SkuSeq > SkuCaseCnt OR SkuCaseCnt = 0)
         ORDER BY RowNo   

         OPEN CUR_ORD

         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey         
         
         SET @n_cnt = 0      
         WHILE @@FETCH_STATUS = 0 AND @n_cnt < @n_NoOfOrderToRelease AND @n_continue IN(1,2)
         BEGIN
            INSERT INTO #TMP_ORDERS (Orderkey)
            VALUES (@c_Orderkey)  
         	  
         	  SET @n_cnt = @n_cnt + 1
            FETCH NEXT FROM CUR_ORD INTO @c_Orderkey         
         END
         CLOSE CUR_ORD
         DEALLOCATE CUR_ORD       	      	
      END
   END                   
                     
   IF @c_Parm01 = 'CS'
   BEGIN   	  
      INSERT INTO #TMP_ORDERS (Orderkey)  
      SELECT Orderkey   
      FROM #TMP_ORDERSSKU
      WHERE SkuSeq <= SkuCaseCnt
      AND  SkuLocMaxQty >= CaseCnt
   END
   
   IF @c_Parm01 = 'PCS'
   BEGIN
      INSERT INTO #TMP_ORDERS 
         (  Orderkey    )  
      SELECT Orderkey   
      FROM #TMP_ORDERSSKU
      WHERE (SkuSeq > SkuCaseCnt OR CaseCnt = 0 OR SkuLocMaxQty < CaseCnt)    
   END
   
QUIT_SP:
   IF @b_Debug = 1
   BEGIN
      SELECT Orderkey
      FROM #TMP_ORDERS
   END

   IF OBJECT_ID('tempdb..#TMP_ORDERSSKU','u') IS NOT NULL
   DROP TABLE #TMP_ORDERSSKU;

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_BuildLoad05'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO