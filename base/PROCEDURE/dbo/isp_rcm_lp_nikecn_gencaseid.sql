SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: isp_RCM_LP_NIKECN_GENCASEID                                      */
/* Creation Date: 11-Feb-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18893 - NIKE CN ECOM Generate CaseID RCM                */ 
/*                                                                      */
/* Called By: Load Plan Dynamic RCM configure at listname 'RCMConfig'   */ 
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 11-Feb-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 11-May-2022  WLChooi  1.1  Bug Fix - Modify Sorting (WL01)           */
/************************************************************************/

CREATE PROC [dbo].[isp_RCM_LP_NIKECN_GENCASEID] 
      @c_Loadkey  NVARCHAR(10),   
      @b_success  INT OUTPUT,
      @n_err      INT OUTPUT,
      @c_errmsg   NVARCHAR(225) OUTPUT,
      @c_code     NVARCHAR(30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue              INT
         , @b_Debug                 INT
         , @n_StartTranCnt          INT
         , @n_MaxPDQty              INT = 0
         , @n_MaxCountPDLoc         INT = 0
         , @c_Storerkey             NVARCHAR(15)
         , @c_Facility              NVARCHAR(5)
         , @c_DocType               NVARCHAR(10)
         , @c_Orderkey              NVARCHAR(10)
         , @c_SKU                   NVARCHAR(20)
         , @c_Loc                   NVARCHAR(10)
         , @c_Pickzone              NVARCHAR(10)
         , @n_Qty                   INT
         , @c_CaseID                NVARCHAR(20) = ''
         , @n_TotalQty              INT = 0
         , @n_SeqNo                 INT = 1
         , @n_CountLoc              INT = 0
         , @n_CountPZ               INT = 0
         , @n_MaxCountPZ            INT = 1
         , @c_NewCaseID             NVARCHAR(10) = 'N'
         , @c_Pickdetailkey         NVARCHAR(10)
         , @c_SQL                   NVARCHAR(MAX)
         , @n_packqty               INT
         , @n_pickqty               INT
         , @n_cnt                   INT
         , @n_splitqty              INT
         , @c_SQLArgument           NVARCHAR(MAX)
         , @c_NewPickdetailkey      NVARCHAR(10)
         , @c_LogicalLoc            NVARCHAR(50)
         , @n_RemainingQty          INT
         , @n_QtyToFit              INT

   SET @b_Debug = @n_err
      
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_Continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   -----Get Load Info-----
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN      
      SELECT @c_Storerkey = MAX(OH.Storerkey)
           , @c_Facility  = MAX(OH.Facility)
           , @c_DocType   = MAX(OH.Doctype)
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
      WHERE LPD.LoadKey = @c_Loadkey                
   END

   -----Get CODELKUP Info-----
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT @n_MaxPDQty      = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CL.Short ELSE 0 END
           , @n_MaxCountPDLoc = CASE WHEN ISNUMERIC(CL.Long) = 1  THEN CL.Long  ELSE 0 END
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'NKECCASEID'
      AND CL.Code = @c_Facility
      AND CL.Storerkey = @c_Storerkey
      AND CL.UDF01 = @c_DocType

      --For Testing Purposes
      IF @b_Debug = 2
      BEGIN
         SET @n_MaxPDQty = 4
         SET @n_MaxCountPDLoc = 2
      END
   END

   ------Validation--------
   IF @n_Continue=1 or @n_Continue=2  
   BEGIN   
      IF @n_MaxPDQty <= 0 OR @n_MaxCountPDLoc <= 0
      BEGIN
         SELECT @n_Continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 67050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)
                          + ': CODELKUP.Short / Long are not numeric value or less than 0 (Listname = NKECCASEID). (isp_RCM_LP_NIKECN_GENCASEID)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END     
   END

   ------Temp Table--------
   IF @n_Continue=1 or @n_Continue=2  
   BEGIN   
      CREATE TABLE #TMP_CASEID (
            Loadkey     NVARCHAR(10)
          , SKU         NVARCHAR(20)
          , LOC         NVARCHAR(10)
          , Pickzone    NVARCHAR(10)
          , Qty         INT
          , CaseID      NVARCHAR(20)
      )

      CREATE TABLE #TMP_LOC (
            LOC         NVARCHAR(10)
      )

      CREATE TABLE #TMP_PZ (
            Pickzone    NVARCHAR(20)
      )
   END

   ------Main Process-------   
   IF (@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      DECLARE cur_LOADORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         WITH CTE1 AS
         (
            SELECT @c_Loadkey AS Loadkey, PD.SKU, PD.LOC, L.PickZone, L.LogicalLocation
                 , SUM(PD.Qty) AS QtyRequired
                 , CASE WHEN SUM(PD.Qty) > @n_MaxPDQty THEN @n_MaxPDQty ELSE 0 END AS MaxQty
                 , CASE WHEN SUM(PD.Qty) > @n_MaxPDQty THEN CAST(SUM(PD.Qty) / @n_MaxPDQty AS INT) ELSE 0 END AS WHOLES 
                 , CASE WHEN SUM(PD.Qty) > @n_MaxPDQty THEN SUM(PD.Qty) % @n_MaxPDQty ELSE SUM(PD.Qty) END AS PARTIALS
            FROM LOADPLANDETAIL LPD (NOLOCK)
            JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = LPD.Orderkey
            JOIN LOC L (NOLOCK) ON L.Loc = PD.Loc
            WHERE LPD.LoadKey = @c_Loadkey
            GROUP BY PD.SKU, PD.LOC, L.PickZone, L.LogicalLocation
            --ORDER BY L.LogicalLocation, PD.LOC, PD.SKU
         )
         ,CTE2 AS 
         (
             SELECT Loadkey, SKU, LOC, Pickzone, LogicalLocation, MaxQty, WHOLES, 'BASE ' AS Remark
             FROM CTE1
             UNION ALL
             SELECT Loadkey, SKU, LOC, Pickzone, LogicalLocation, MaxQty, WHOLES - 1, 'RECUR' AS Remark
             FROM CTE2 
             WHERE WHOLES > 1
         )
         SELECT Loadkey, SKU, LOC, Pickzone, LogicalLocation, MaxQty AS QuantityRequired 
         FROM CTE2
         WHERE MaxQty > 0
         UNION ALL
         SELECT Loadkey, SKU, LOC, Pickzone, LogicalLocation, PARTIALS AS QuantityRequired 
         FROM CTE1 
         WHERE PARTIALS > 0
         ORDER BY PickZone ASC, LogicalLocation ASC, LOC ASC, SKU ASC, QuantityRequired DESC   --WL01

      OPEN cur_LOADORDER  
      FETCH NEXT FROM cur_LOADORDER INTO @c_Loadkey, @c_SKU, @c_Loc, @c_Pickzone, @c_LogicalLoc, @n_Qty
      
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2) 
      BEGIN   
         --Insert Loc into temp table, if current NoOfLoc in temp table >= Max Count Loc, create new CaseID
         IF NOT EXISTS (SELECT 1 FROM #TMP_LOC WHERE LOC = @c_Loc)
         BEGIN
            SELECT @n_CountLoc = COUNT(1)
            FROM #TMP_LOC TL
            
            IF @n_CountLoc >= @n_MaxCountPDLoc
            BEGIN
               TRUNCATE TABLE #TMP_LOC
               SET @c_NewCaseID = 'Y'
            END
         
            INSERT INTO #TMP_LOC(LOC)
            SELECT @c_Loc
         END
         
         --Insert Pickzone into temp table, if current NoOfPickzone in temp table >= Max Count Pickzone, create new CaseID
         IF NOT EXISTS (SELECT 1 FROM #TMP_PZ WHERE Pickzone = @c_Pickzone)
         BEGIN
            SELECT @n_CountPZ = COUNT(1)
            FROM #TMP_PZ TP
         
            IF @n_CountPZ >= @n_MaxCountPZ
            BEGIN
               TRUNCATE TABLE #TMP_PZ
               TRUNCATE TABLE #TMP_LOC

               INSERT INTO #TMP_LOC(LOC)
               SELECT @c_Loc

               SET @c_NewCaseID = 'Y'
            END
         
            INSERT INTO #TMP_PZ(Pickzone)
            SELECT @c_Pickzone
         END
         
         IF @b_Debug = 1
         BEGIN
            SELECT @n_TotalQty      AS '@n_TotalQty'
                 , @n_Qty           AS '@n_Qty'
                 , @n_MaxPDQty      AS '@n_MaxPDQty'
                 , @n_CountLoc      AS '@n_CountLoc'
                 , @n_MaxCountPDLoc AS '@n_MaxCountPDLoc'
                 , @n_SeqNo         AS '@n_SeqNo'
         END

         --Scenario 0: Check if can fit current CaseID
         SET @n_RemainingQty = 0
         IF @n_TotalQty < @n_MaxPDQty AND @c_NewCaseID <> 'Y' AND @n_TotalQty > 0
         BEGIN
            --Scenario 1
            --IF @n_MaxPDQty = 200, @n_TotalQty = 40 THEN @n_RemainingQty = 160
            --@n_Qty = 150, Since @n_Qty < @n_RemainingQty THEN can fit @n_Qty (150)
            --@n_Qty = 0, @n_TotalQty = @n_TotalQty + @n_QtyToFit = 40 + 150 = 190
            --Scenario 2
            --IF @n_MaxPDQty = 200, @n_TotalQty = 60 THEN @n_RemainingQty = 140
            --@n_Qty = 150, Since @n_Qty > @n_RemainingQty THEN only can fit @n_RemainingQty (140)
            --@n_Qty = 10, @n_TotalQty = @n_TotalQty + @n_QtyToFit = 60 + 140 = 200
            --@n_Qty = 10 need to fit into next CaseID

            SET @n_RemainingQty = @n_MaxPDQty - @n_TotalQty
            SET @n_QtyToFit = CASE WHEN @n_Qty < @n_RemainingQty THEN @n_Qty ELSE @n_RemainingQty END
            SET @n_Qty = @n_Qty - @n_QtyToFit
            SET @n_TotalQty = @n_TotalQty + @n_QtyToFit
            SET @c_CaseID = @c_Loadkey + RIGHT(REPLICATE('0',3) + CAST(@n_SeqNo AS NVARCHAR), 3)

            INSERT INTO #TMP_CASEID(Loadkey, SKU, LOC, Pickzone, Qty, CaseID)
            SELECT @c_Loadkey, @c_SKU, @c_Loc, @c_Pickzone, @n_QtyToFit, @c_CaseID

            IF @n_Qty <=0
               GOTO NEXT_LOOP
         END

         --Scenario 1: New CaseID -> Qty > MaxQty, add into current CaseID, then increment CaseID SeqNo
         IF @n_Qty >= @n_MaxPDQty AND @n_TotalQty = 0
         BEGIN
            SET @n_TotalQty = 0
            SET @c_CaseID = @c_Loadkey + RIGHT(REPLICATE('0',3) + CAST(@n_SeqNo AS NVARCHAR), 3)

            INSERT INTO #TMP_CASEID(Loadkey, SKU, LOC, Pickzone, Qty, CaseID)
            SELECT @c_Loadkey, @c_SKU, @c_Loc, @c_Pickzone, @n_Qty, @c_CaseID

            SET @n_SeqNo = @n_SeqNo + 1
         END
         ELSE
         BEGIN
            --Scenario 2: New CaseID -> Qty + QtyInCaseID > MaxQty, add into a new CaseID
            IF @n_TotalQty + @n_Qty > @n_MaxPDQty
            BEGIN
               SET @n_TotalQty = @n_Qty
               SET @n_SeqNo = @n_SeqNo + 1
               SET @c_CaseID = @c_Loadkey + RIGHT(REPLICATE('0',3) + CAST(@n_SeqNo AS NVARCHAR), 3)
          
               INSERT INTO #TMP_CASEID(Loadkey, SKU, LOC, Pickzone, Qty, CaseID)
               SELECT @c_Loadkey, @c_SKU, @c_Loc, @c_Pickzone, @n_Qty, @c_CaseID
            END
            ELSE
            BEGIN
               --Scenario 3: New CaseID -> if NoOfLoc > MaxCountLoc OR NoOfPickzone > MaxCountPickzone, add into a new CaseID
               IF @c_NewCaseID = 'Y'
               BEGIN
                  SET @n_TotalQty = @n_Qty
                  SET @n_SeqNo = @n_SeqNo + 1

                  SET @c_CaseID = @c_Loadkey + RIGHT(REPLICATE('0',3) + CAST(@n_SeqNo AS NVARCHAR), 3)
                  
                  INSERT INTO #TMP_CASEID(Loadkey, SKU, LOC, Pickzone, Qty, CaseID)
                  SELECT @c_Loadkey, @c_SKU, @c_Loc, @c_Pickzone, @n_Qty, @c_CaseID

                  SET @c_NewCaseID = 'N'
               END
               ELSE
               --Scenario 4: Qty add into current CaseID
               BEGIN
                  SET @c_CaseID = @c_Loadkey + RIGHT(REPLICATE('0',3) + CAST(@n_SeqNo AS NVARCHAR), 3)
                  
                  INSERT INTO #TMP_CASEID(Loadkey, SKU, LOC, Pickzone, Qty, CaseID)
                  SELECT @c_Loadkey, @c_SKU, @c_Loc, @c_Pickzone, @n_Qty, @c_CaseID
                  
                  SET @n_TotalQty = @n_TotalQty + @n_Qty
               END
            END
         END

         NEXT_LOOP:
         FETCH NEXT FROM cur_LOADORDER INTO @c_Loadkey, @c_SKU, @c_Loc, @c_Pickzone, @c_LogicalLoc, @n_Qty 
      END
      CLOSE cur_LOADORDER  
      DEALLOCATE cur_LOADORDER                                   
   END  

   --Update CaseID to Pickdetail / Split Pickdetail
   IF (@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TC.LOC, TC.SKU, TC.Pickzone, TC.CaseID, TC.Qty
      FROM #TMP_CASEID TC

      OPEN CUR_UPD

      FETCH NEXT FROM CUR_UPD INTO @c_Loc, @c_SKU, @c_Pickzone, @c_CaseID, @n_packqty

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @c_pickdetailkey = ''  

         WHILE @n_packqty > 0  
         BEGIN
            SET @n_cnt = 0  

            SELECT TOP 1 @n_cnt = 1
                        ,@n_pickqty = PICKDETAIL.Qty
                        ,@c_pickdetailkey = PICKDETAIL.Pickdetailkey 
            FROM PICKDETAIL WITH (NOLOCK) 
            JOIN ORDERS WITH (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey 
            JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
            JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey  
            JOIN LOC WITH (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC
            WHERE LOADPLANDETAIL.Loadkey = @c_loadkey  
            AND PICKDETAIL.Sku = @c_SKU  
            AND PICKDETAIL.LOC = @c_Loc
            AND LOC.PickZone = @c_Pickzone
            AND PICKDETAIL.storerkey = @c_Storerkey
            AND PICKDETAIL.CaseID = ''
            AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey   
            ORDER BY PICKDETAIL.Pickdetailkey

            IF @n_cnt = 0  
               BREAK

            IF @n_pickqty <= @n_packqty  
            BEGIN  
               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET PICKDETAIL.CaseID = @c_CaseID 
                  ,TrafficCop = NULL  
                  ,EditWho = SUSER_SNAME()
                  ,EditDate = GETDATE()
               WHERE Pickdetailkey = @c_pickdetailkey  
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63331  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (isp_RCM_LP_NIKECN_GENCASEID)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  BREAK  
               END  
               SELECT @n_packqty = @n_packqty - @n_pickqty  
            END  
            ELSE  
            BEGIN  -- pickqty > packqty  
               SELECT @n_splitqty = @n_pickqty - @n_packqty  
               EXECUTE nspg_GetKey  
               'PICKDETAILKEY',  
               10,  
               @c_newpickdetailkey OUTPUT,  
               @b_success OUTPUT,  
               @n_err OUTPUT,  
               @c_errmsg OUTPUT  
               IF NOT @b_success = 1  
               BEGIN  
                  SELECT @n_continue = 3  
                  BREAK  
               END  
         
               INSERT PICKDETAIL  
               (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,  
                Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,  
                DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,  
                WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, Channel_ID,
                TaskDetailKey, Notes
               )  
               SELECT @c_newpickdetailkey  
                    , ''  
                    , PickHeaderKey, OrderKey, OrderLineNumber, Lot
                    , Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status  
                    , ''                             
                    , Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType
                    , ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod 
                    , WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, Channel_ID
                    , TaskDetailKey, Notes
               FROM PICKDETAIL (NOLOCK)  
               WHERE PickdetailKey = @c_pickdetailkey  
         
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63332  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (isp_RCM_LP_NIKECN_GENCASEID)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  BREAK  
               END  
         
               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET PICKDETAIL.CaseID = @c_CaseID 
                  ,Qty = @n_packqty  
                  ,UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END   
                  ,TrafficCop = NULL  
                  ,EditWho = SUSER_SNAME()
                  ,EditDate = GETDATE()
                WHERE Pickdetailkey = @c_pickdetailkey  

                SELECT @n_err = @@ERROR  

                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63333  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (isp_RCM_LP_NIKECN_GENCASEID)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                   BREAK  
                END  
         
               SELECT @n_packqty = 0  
            END  
         END -- While packqty > 0
         NEXT_LOOP_UPD:
         FETCH NEXT FROM CUR_UPD INTO @c_Loc, @c_SKU, @c_Pickzone, @c_CaseID, @n_packqty
      END
      CLOSE CUR_UPD
      DEALLOCATE CUR_UPD
   END

   --For Testing Purposes
   IF @b_Debug IN (1,2,9)
   BEGIN
      SELECT '#TMP_CASEID' AS [Source], * FROM #TMP_CASEID
      ORDER BY caseid
   END

   RETURN_SP:
   IF (SELECT CURSOR_STATUS('LOCAL','cur_LOADORDER')) >=0 
   BEGIN
      CLOSE cur_LOADORDER           
      DEALLOCATE cur_LOADORDER      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_UPD')) >=0 
   BEGIN
      CLOSE CUR_UPD           
      DEALLOCATE CUR_UPD      
   END

   IF OBJECT_ID('tempdb..#TMP_CASEID') IS NOT NULL
      DROP TABLE #TMP_CASEID

   IF OBJECT_ID('tempdb..#TMP_LOC') IS NOT NULL
      DROP TABLE #TMP_LOC

   IF OBJECT_ID('tempdb..#TMP_PZ') IS NOT NULL
      DROP TABLE #TMP_PZ

   IF @n_Continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RCM_LP_NIKECN_GENCASEID'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO