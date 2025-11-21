SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/*******************************************************************************/
/* Stored Procedure: isp_HM_MarkOrder                                   		 */
/* Creation Date: 11-Jun-2020                                           		 */
/* Copyright: LF Logistics                                              		 */
/* Written by: Josh Yan (CN)                                            		 */
/*                                                                      		 */
/* Purpose: CN H&M Mark order process for D11                           		 */
/*                                                                      		 */
/* Called By: Backend Schedule Job                                      		 */
/*                                                                      		 */
/* PVCS Version: 1.0                                                    		 */
/*                                                                      		 */
/* Version: 7.0                                                         		 */
/*                                                                      		 */
/* Data Modifications:                                                  		 */
/*                                                                      		 */
/* Updates:                                                             		 */
/* Date         Author  Ver     Purposes                                		 */
/* 2020/07/09   kocy    V1.0    https://jiralfl.atlassian.net/browse/WMS-13511 */
/* 2020/11/01   Josh    V1.1    Performance tune                               */
/*******************************************************************************/
    
CREATE PROC [dbo].[isp_HM_MarkOrder]    
AS    
BEGIN    
   SET NOCOUNT ON;    
   SET ANSI_NULLS OFF;    
   SET QUOTED_IDENTIFIER OFF;    
   SET CONCAT_NULL_YIELDS_NULL OFF;    
    
   DECLARE @b_debug int = 0;    
   DECLARE @c_TargetNum nvarchar(10);    
   DECLARE @c_StartOrderDate nvarchar(20);    
   DECLARE @c_EndOrderDate nvarchar(20);    
   DECLARE @c_StorerKey nvarchar(15);    
   DECLARE @Orderkey nvarchar(30);    
   DECLARE @c_Sku nvarchar(20);    
   DECLARE @n_OriginalQTY int;    
   DECLARE @n_InvLeftQTY int;    
   DECLARE @n_isMark int;    
    
    
   DECLARE @c_SQL nvarchar(max),    
           @c_SQLParm nvarchar(max);    
    
   DECLARE @n_Continue int,    
           @n_StartTCnt int,    
           @b_Success int,    
           @n_Err int,    
           @c_ErrMsg nvarchar(250);    
    
   SELECT    
      @n_StartTCnt = @@TRANCOUNT,    
      @n_Continue = 1,    
      @b_Success = 1,    
      @n_Err = 0,    
      @c_ErrMsg = N'';    
    
   SET @c_StorerKey = N'18441';    
    
   IF @@TRANCOUNT = 0    
      BEGIN TRAN;    
    
      SELECT    
         @c_TargetNum = ISNULL(Short, ''),    
         @c_StartOrderDate = ISNULL(UDF01, ''),    
         @c_EndOrderDate = ISNULL(UDF02, '')    
      FROM dbo.CODELKUP WITH (NOLOCK)    
      WHERE LISTNAME = 'HMORDMARK'    
      AND Storerkey = @c_StorerKey;    
    
      IF (ISNUMERIC(@c_TargetNum) * ISDATE(@c_StartOrderDate) * ISDATE(@c_EndOrderDate)) = 0    
      BEGIN    
         SELECT @n_Continue = 3;    
         SELECT @n_Err = 63331;    
         SELECT @c_ErrMsg = CONVERT(char(250), @n_Err);    
         SELECT @c_ErrMsg = N'NSQL' + CONVERT(char(5), @n_Err) + N': Input Data Error! (isp_HM_MarkOrder)';    
         GOTO Quit_SP;    
      END;    
    
    
      -------------------------ΦÄ╖σÅûΦ«óσìò--------------------      
      CREATE TABLE #tempOrdersScope (    
         Orderkey nvarchar(10) NOT NULL PRIMARY KEY    
      );    
      CREATE TABLE #tempSKUScope (    
         SKU nvarchar(20) NOT NULL PRIMARY KEY    
      );    
      CREATE TABLE #tempMarkOrders (    
         Orderkey nvarchar(10) NOT NULL PRIMARY KEY    
      );    
      CREATE TABLE #tempODSKU (    
         Orderkey nvarchar(10),    
         SKU nvarchar(20),    
         OriginalQty int,    
         CONSTRAINT PK_#tempODSKU PRIMARY KEY (Orderkey,SKU)    
      ); --Josh remove sku    
      CREATE TABLE #tempInv (    
         SKU nvarchar(20),    
         INVQTY int,    
         USEQTY int,    
         CONSTRAINT PK_#tempInvSKU PRIMARY KEY (SKU)    
      ); --Josh create table     
    
      SET @c_SQL    
      = N'        
   INSERT INTO #tempOrdersScope (Orderkey)        
   SELECT   TOP ' + @c_TargetNum    
      + N' OrderKey        
   FROM     dbo.ORDERS o (NOLOCK)        
   WHERE    StorerKey = @c_StorerKey        
            AND Status = ''0''        
            AND M_Address1 <> ''P''        
            AND o.OrderDate > @c_StartOrderDate        
      AND o.OrderDate < @c_EndOrderDate ';    
    
      IF @b_debug = 1    
      BEGIN    
         PRINT @c_SQL;    
      END;    
    
      SET @c_SQLParm = N'@c_StorerKey NVARCHAR(15), @c_StartOrderDate NVARCHAR(20), @c_EndOrderDate NVARCHAR(20)';    
      EXEC sp_executesql @c_SQL,    
                         @c_SQLParm,    
                         @c_StorerKey,    
                         @c_StartOrderDate,    
                         @c_EndOrderDate;    
    
      INSERT INTO #tempSKUScope (SKU)    
         SELECT DISTINCT    
            od.Sku    
         FROM #tempOrdersScope os (NOLOCK)    
         INNER JOIN dbo.ORDERDETAIL od (NOLOCK)    
            ON od.OrderKey = os.Orderkey;    
    
      IF (@b_debug = 1)    
      BEGIN    
         PRINT 'Completed IDX_TEMPSKUSCOPE';    
      END;    
    
      ------------------------- µáçΦ«░flag Σ╕║ P --------------        
      INSERT INTO #tempInv (SKU, INVQTY, USEQTY)    
         SELECT    
            lli.Sku,    
            SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) AS INVQTY,    
            0 AS USEQTY    
         FROM dbo.LOTxLOCxID lli (NOLOCK)    
         INNER JOIN dbo.LOTATTRIBUTE la (NOLOCK) ON la.StorerKey = lli.StorerKey    
               AND la.Sku = lli.Sku    
               AND la.Lot = lli.Lot    
         INNER JOIN dbo.LOC l (NOLOCK) ON l.Loc = lli.Loc    
         WHERE l.Facility = 'HM'    
         AND la.Lottable03 = 'STD'    
         AND l.Status = 'OK'    
         AND l.LocationFlag = 'NONE'    
         AND l.LocationType = 'PICK'    
         AND la.StorerKey = @c_StorerKey    
         AND EXISTS (SELECT 1 FROM #tempSKUScope ss (NOLOCK) WHERE ss.SKU = la.Sku)             
         GROUP BY lli.Sku    
         HAVING SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked) > 0 ;    
    
      IF @b_debug = 1    
      BEGIN    
         PRINT 'Completed Create #tempInv';    
      END;    
    
      IF @b_debug = 1    
      BEGIN    
         PRINT 'Start Calc ORD';    
      END;    
    
      INSERT INTO #tempODSKU (Orderkey, SKU, OriginalQty)    
         SELECT    
            OD.OrderKey,    
            OD.Sku,    
            ISNULL(SUM(OD.OriginalQty), 0) AS OriginalQty    
         FROM #tempOrdersScope TOS    
         JOIN dbo.ORDERDETAIL OD (NOLOCK) ON TOS.Orderkey = OD.OrderKey    
         GROUP BY OD.OrderKey, OD.Sku;    
    
      DECLARE OrdCalc_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT    
         Orderkey    
      FROM #tempOrdersScope(NOLOCK);    
    
      OPEN OrdCalc_CUR;    
    
      FETCH NEXT FROM OrdCalc_CUR    
      INTO @Orderkey;    
    
      WHILE @@Fetch_Status = 0    
      BEGIN    
         /* Josh V1.1 Start */    
         SET @n_isMark = 1;    
         SET @c_Sku = N'';    
         SET @n_OriginalQTY = 0;    
    
         DECLARE OrdChcekMark_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT    
            SKU,    
            OriginalQty    
         FROM #tempODSKU(NOLOCK)    
         WHERE Orderkey = @Orderkey;    
    
         OPEN OrdChcekMark_CUR;    
    
         FETCH NEXT FROM OrdChcekMark_CUR    
         INTO @c_Sku,    
         @n_OriginalQTY;    
    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            SET @n_InvLeftQTY = 0    
            SELECT @n_InvLeftQTY = INVQTY - USEQTY    
            FROM #tempInv(NOLOCK)    
            WHERE Sku = @c_Sku;    
    
            IF @n_InvLeftQTY - @n_OriginalQTY < 0    
            BEGIN    
               SET @n_isMark = 0;    
            END;    
    
            FETCH NEXT FROM OrdChcekMark_CUR    
        INTO @c_Sku, @n_OriginalQTY;    
         END;    
    
         CLOSE OrdChcekMark_CUR;    
         DEALLOCATE OrdChcekMark_CUR;    
    
         IF @n_isMark = 1    
         BEGIN    
            UPDATE inv    
            SET inv.USEQTY = inv.USEQTY + A.OriginalQty    
            FROM #tempODSKU AS A    
            JOIN #tempInv inv (NOLOCK)    
               ON inv.Sku = A.SKU    
            WHERE A.Orderkey = @Orderkey;    
    
            INSERT INTO #tempMarkOrders (Orderkey)    
               VALUES (@Orderkey);    
         END;    
         /* Josh V1.1 End */    
    
         --IF NOT EXISTS      
         --(      
         --    SELECT 1      
         --    FROM #tempODSKU A      
         --        LEFT JOIN #tempInv inv (NOLOCK)      
         --            ON inv.Sku = A.SKU      
         --    WHERE (      
         --              (inv.INVQTY - inv.USEQTY - A.OriginalQty) < 0      
         --              OR inv.Sku IS NULL      
         --          )      
         --          AND A.Orderkey = @Orderkey      
         --)      
         --BEGIN      
         --    UPDATE inv      
         --    SET inv.USEQTY = inv.USEQTY + A.OriginalQty      
         --    FROM #tempODSKU AS A      
         --        JOIN #tempInv inv (NOLOCK)      
         --            ON inv.Sku = A.SKU      
         --    WHERE A.Orderkey = @Orderkey;      
    
         --    INSERT INTO #tempMarkOrders      
         --    (      
         --        Orderkey      
         --    )      
         --    VALUES      
         --    (@Orderkey);      
         --END;      
    
    
         FETCH NEXT FROM OrdCalc_CUR    
         INTO @Orderkey;    
      END;    
    
      CLOSE OrdCalc_CUR;    
      DEALLOCATE OrdCalc_CUR;    
    
      IF @b_debug = 1    
      BEGIN    
         SELECT    
            COUNT(DISTINCT o.Orderkey) AS 'TotalNeedMarkOrders',    
            SUM(od.OriginalQty) AS 'TotalCanPickQTY'    
         FROM #tempMarkOrders o (NOLOCK)    
         INNER JOIN dbo.ORDERDETAIL od (NOLOCK) ON od.OrderKey = o.Orderkey;    
      END;    
    
      ----------------------Mark Order        
      DECLARE OrdMark_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT Orderkey    
      FROM #tempMarkOrders(NOLOCK);    
    
      OPEN OrdMark_CUR;    
    
      FETCH NEXT FROM OrdMark_CUR    
      INTO @Orderkey;    
    
      WHILE @@Fetch_Status = 0 AND @n_Continue IN (1, 2)    
      BEGIN    
    
         UPDATE dbo.ORDERS WITH (ROWLOCK)    
         SET M_Address1 = 'P',    
             TrafficCop = NULL,    
             EditDate = GETDATE(),    
             EditWho = SUSER_SNAME()    
         WHERE OrderKey = @Orderkey    
         AND Status = '0';    
    
         SELECT @n_Err = @@ERROR;    
         IF @n_Err <> 0    
         BEGIN    
            SELECT @n_Continue = 3;    
            SELECT @c_ErrMsg = CONVERT(char(250), @n_Err), @n_Err = 63330;    
            SELECT    
               @c_ErrMsg    
               = N'NSQL' + CONVERT(char(5), @n_Err) + N': Update Ordersr Failed! (isp_HM_MarkOrder)' + N' ( '    
               + N' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + N' ) ';    
         END;    
    
         IF @b_debug = 1    
         BEGIN    
            PRINT @Orderkey;    
         END;    
         FETCH NEXT FROM OrdMark_CUR    
         INTO @Orderkey;    
      END;    
    
      CLOSE OrdMark_CUR;    
      DEALLOCATE OrdMark_CUR;    
    
      DROP TABLE #tempOrdersScope;    
      DROP TABLE #tempSKUScope;    
      DROP TABLE #tempInv;    
      DROP TABLE #tempMarkOrders;    
      DROP TABLE #tempODSKU;    
    
   QUIT_SP:    
    
      IF @n_Continue = 3 -- Error Occured - Process And Return              
      BEGIN    
         SELECT    
            @b_Success = 0;    
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
         BEGIN    
            ROLLBACK TRAN;    
         END;    
         ELSE    
         BEGIN    
            WHILE @@TRANCOUNT > @n_StartTCnt    
            BEGIN    
            COMMIT TRAN;    
         END;    
     END;    
      EXECUTE nsp_logerror @n_Err,    
                           @c_ErrMsg,    
                           'isp_HM_MarkOrder';    
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR;    
      RETURN;    
   END;    
   ELSE    
   BEGIN    
      SELECT @b_Success = 1;    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN;    
      END;    
      RETURN;    
   END;    
END;

GO