SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: ispRLWAV02                                          */
/* Creation Date: 31-Oct-2013                                            */
/* Copyright: IDS                                                        */
/* Written by: YTWan                                                     */
/*                                                                       */
/* Purpose: SOS#293386 Release Pick Task                                 */
/*                                                                       */
/* Called By: wave                                                       */
/*                                                                       */
/* PVCS Version: 2.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Ver   Purposes                                   */
/* 09-MAY-2014 YTWan    1.0   Fixed to Handle print pickslip Report and  */
/*                            then release wave (Wan01)                  */
/* 18-MAY-2014 Chee     1.1   Add validation to make sure make sure      */
/*                            loadkey not exists in multiple wave        */
/*                            Add validation to make sure all allocation */
/*                            from BULK location have UCCNo stamped in   */
/*                            PickDetail.DropID                          */
/*                            Add validation to make sure all pickdetail */
/*                            have taskdetailkey stamped (Chee01)        */
/* 23-05-2014  Shong    1.2   Generate Replen Task by UCC Level          */
/* 22-May-2014 YTWan    1.3   Add Validation, Different loadkey with same*/
/*                            loadplan group not allow. (Wan02)          */
/* 01-06-2014  ChewKP   1.4   Add UCC to TaskDetail.CaseID for RPF task  */
/*                            (ChewKP01)                                 */
/* 18-06-2014  ChewKP   1.5   Prevent Wrong LoadPlan Mode being selected */
/*                            (ChewKP02)                                 */
/* 19-06-2014  ChewKP   1.6   Allow Release when Orders.Status = '3'     */
/*                            (ChewKP03)                                 */
/* 23-07-2014  ChewKP   1.7   Add Validation for DctoDc Cannot > 1 Orders*/
/*                            for same SKU in a Wave (ChewKP04)          */
/* 17-JUN-2014 YTWan    1.4   SOS#313140 - DTC Pick Task Release Strategy*/
/*                            (Wan03)                                    */
/* 01-AUG-2014 ChewKP   1.5   Add OrderKey for DTC -- (ChewKP05)         */
/* 12-AUG-2014 YTWan    1.6   SOS#318252 - ANF - Retail RPF Task Priority*/
/*                            Update (Wan04)                             */
/* 11-Aug-2016 TLTING01 1.7   Performance tune                           */
/* 18-JAN-2017 CheeMun  1.8   IN00245886 - Additional PickHeader check.  */
/* 27-Feb-2017 TLTING   1.9   Variable Nvarchar                          */
/* 10-Jul-2017 JHTAN    2.0   IN00390534 Task Manager error (JH01)       */
/* 01-04-2020  Wan01    2.1   Sync Exceed & SCE                          */
/*************************************************************************/

CREATE PROCEDURE [dbo].[ispRLWAV02]
                 @c_wavekey      NVARCHAR(10)
                ,@b_Success      int        OUTPUT
                ,@n_err          int        OUTPUT
                ,@c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @n_continue int,
                @n_starttcnt int,         -- Holds the current transaction count
                @n_debug int,
                @n_cnt int
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
   SELECT @n_debug = 1

   DECLARE @c_OrderType             NVARCHAR(10)
         , @c_Orderkey              NVARCHAR(10)
         , @c_Consigneekey          NVARCHAR(15)
         , @c_PickToZone            NVARCHAR(30)
         , @c_Storerkey             NVARCHAR(15)
         , @c_Sku                   NVARCHAR(20)
         , @c_Lot                   NVARCHAR(10)
         , @c_FromLoc               NVARCHAR(10)
         , @c_ID                    NVARCHAR(18)
         , @n_Qty                   INT
         , @n_UCCQty                INT
         , @n_QtyPA                 INT
         --,@n_QtyLoose INT

         , @c_Areakey               NVARCHAR(10)
         , @c_Facility              NVARCHAR(5)
         , @c_NextDynPickLoc        NVARCHAR(10)
         , @c_Packkey               NVARCHAR(10)
         , @c_UOM                   NVARCHAR(10)
         , @c_DestinationType       NVARCHAR(10)
         , @n_LocCubeAvailable      DECIMAL(13,5)
         , @n_LocCartonAllow        INT
         , @n_CartonToReplen        INT
         , @c_Lottable01            NVARCHAR(18)
         , @c_Lottable02            NVARCHAR(18)
         , @c_Lottable03            NVARCHAR(18)
         , @c_DropId                NVARCHAR(20)

         , @c_Pickslipno            NVARCHAR(10)
         , @c_Loadkey               NVARCHAR(10)
         , @c_PickZone              NVARCHAR(10)

         , @n_Pickqty               INT
         , @n_ReplenQty             INT
         , @n_SplitQty              INT
         , @c_Pickdetailkey         NVARCHAR(18)
         , @c_NewPickdetailKey      NVARCHAR(18)


         , @c_Taskdetailkey         NVARCHAR(10)
         , @c_TaskType              NVARCHAR(10)
         , @c_PickMethod            NVARCHAR(10)
         , @c_Toloc        NVARCHAR(10)
         , @c_SourceType            NVARCHAR(30)
         , @c_Message03             NVARCHAR(20)

         , @c_WCS                   NVARCHAR(10)

         , @n_SeqNo                 INT
         , @n_PutawayCapacity       INT
         , @c_userid                NVARCHAR(18)
         , @c_PickAndDropLoc        NVARCHAR(10)

         , @c_LogicalFromLoc        NVARCHAR(18)
         , @c_LogicalToLoc          NVARCHAR(18)

         , @c_PDet_DropID           NVARCHAR(20)

         , @n_CountLoadPlan         INT
         , @n_CountOrderGroup       INT
         , @c_OrderGroupSectionKey  NVARCHAR(30)  --(JH01)
   --(Wan02) - START
   DECLARE @c_ListName              NVARCHAR(10)
         , @c_TableColumnName       NVARCHAR(250)
         , @c_SQLGroup              NVARCHAR(2000)
         , @c_SQL                   NVARCHAR(4000)
         , @n_Found                 INT
   --(Wan02) - END
           , @c_Priority              NVARCHAR(10)   --(Wan04)
           , @c_curPickdetailkey    NVARCHAR(10)

   SET @c_Areakey         = ''
   SET @n_PutawayCapacity = ''
   SET @c_userid          = SUSER_NAME()
   SET @c_PickAndDropLoc  = ''
   SET @c_Orderkey        = ''                  --(ChewKP05)
   SET @c_Priority        = '9'                       --(Wan04)

   SET @c_DropID          = ''
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   -----Wave Validation-----

   -----Determine order type ECOM(L) Or Retail/Wholesale(N)-----

   SELECT TOP 1 @c_Storerkey = OH.Storerkey
               ,@c_OrderType = CASE WHEN OH.Type = 'DTC' THEN 'DTC' ELSE 'PTS' END
               ,@c_Facility  = OH.Facility
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey
   -----Determine order type ECOM(L) Or Retail/Wholesale(N)-----

   IF ISNULL(@c_wavekey,'') = ''
   BEGIN
      SET @n_continue = 3
      SET @n_err = 81000
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV02)'
      GOTO RETURN_SP
   END


   IF EXISTS ( SELECT 1 FROM TASKDETAIL TD WITH (NOLOCK)
               WHERE TD.Wavekey = @c_Wavekey
               AND TD.Sourcetype IN('ispRLWAV02-RETAIL','ispRLWAV02-ECOM')
               AND TD.Tasktype IN ('RPF', 'SPK', 'PK') )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 81001
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has beed released. (ispRLWAV02)'
      GOTO RETURN_SP
   END

   -- (ChewKP03)
   IF EXISTS ( SELECT 1
               FROM WAVEDETAIL WD WITH (NOLOCK)
               JOIN ORDERS O WITH (NOLOCK) ON WD.Orderkey = O.Orderkey
               WHERE O.Status > '5'
               AND WD.Wavekey = @c_Wavekey)
   BEGIN
      SET @n_continue = 3
      SET @n_err = 81002
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV02)'
      GOTO RETURN_SP
   END

   IF EXISTS ( SELECT 1
               FROM WAVEDETAIL WD WITH (NOLOCK)
               JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
               WHERE WD.Wavekey = @c_Wavekey
               GROUP BY WD.Wavekey
               HAVING COUNT( DISTINCT CASE WHEN OH.Type = 'DTC' THEN 'DTC' ELSE 'PTS' END ) > 1)
   BEGIN
      SET @n_continue = 3
      SET @n_err = 81003
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Mix order type in this Wave (ispRLWAV02)'
      GOTO RETURN_SP
   END

   -- Make sure loadkey not exists in multiple wave (Chee01)
   IF EXISTS ( SELECT 1
               FROM LoadPlanDetail LPD WITH (NOLOCK)
               JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = LPD.OrderKey
               WHERE EXISTS(SELECT 1 FROM WAVEDETAIL W WITH (NOLOCK)
                            JOIN LoadplanDetail LPD2 WITH (NOLOCK) ON LPD2.OrderKey = W.OrderKey
                            WHERE LPD2.LoadKey = LPD.LoadKey
                              AND W.WaveKey = @c_Wavekey)
               GROUP BY LPD.LoadKey
               HAVING COUNT(DISTINCT O.UserDefine09) > 1 )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 81014
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Found loadkey exists in multiple wave. (ispRLWAV02)'
      GOTO RETURN_SP
   END

   -- Make sure all allocation from BULK location have UCCNo stamped in PickDetail.DropID (Chee01)
   IF EXISTS ( SELECT 1
               FROM PickDetail PD WITH (NOLOCK)
               JOIN WaveDetail WD WITH (NOLOCK) ON PD.OrderKey = WD.OrderKey
               JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.LOC)
               WHERE WD.Wavekey = @c_Wavekey
                 AND LOC.LocationType = 'OTHER'
                 AND LOC.LocationCategory = 'SELECTIVE'
                 AND ISNULL(PD.DropID, '') = '' )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 81015
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Found PickDetail record without UCCNo. Please reallocate. (ispRLWAV02)'
      GOTO RETURN_SP
   END

    --(Wan02) - START - Check unique loadplan group
   SET @c_listname = ''
   SELECT @c_listname = ISNULL(RTRIM(CODELIST.Listname),'')
   FROM WAVE     WITH (NOLOCK)
   JOIN CODELIST WITH (NOLOCK) ON WAVE.LoadPlanGroup = CODELIST.Listname AND CODELIST.ListGroup = 'WAVELPGROUP'
   WHERE WAVE.Wavekey = @c_WaveKey

   IF @c_listname <> ''
   BEGIN
      DECLARE CUR_CODELKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TOP 10  Long
      FROM   CODELKUP WITH (NOLOCK)
      WHERE  ListName = @c_ListName
      ORDER BY Code

      OPEN CUR_CODELKUP

      FETCH NEXT FROM CUR_CODELKUP INTO @c_TableColumnName

      SET @c_SQLGroup = ''
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_SQLGroup = @c_SQLGroup + @c_TableColumnName + ', '
     FETCH NEXT FROM CUR_CODELKUP INTO @c_TableColumnName
      END
      CLOSE CUR_CODELKUP
      DEALLOCATE CUR_CODELKUP

      IF RIGHT(@c_SQLGroup,2) = ', '
      BEGIN
         SET @c_SQLGroup = SUBSTRING(@c_SQLGroup,1 ,LEN(@c_SQLGroup) - 1)
      END

      IF LEN(@c_SQLGroup) > 0
      BEGIN
         SET @n_Found = 0
         SET @c_SQL = ' SELECT @n_Found = 1'
                    + ' FROM  WAVEDETAIL WITH (NOLOCK)'
                    + ' JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)'
                    + ' WHERE WAVEDETAIL.Wavekey = @c_Wavekey'
                    + ' GROUP BY ' + @c_SQLGroup
                    + ' HAVING COUNT(DISTINCT ORDERS.Loadkey) > 1'


         EXEC sp_executesql @c_SQL
                          , N' @c_Wavekey NVARCHAR(10), @n_Found INT OUTPUT'
                          , @c_Wavekey
                          , @n_Found OUTPUT

         IF @n_Found = 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 81019
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Different Loadkey with same Loadplan group Found. (ispRLWAV02)'
            GOTO RETURN_SP
         END
      END
   END
   --(Wan02) - END

   -- (ChewKP02)
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
       SET @n_CountLoadPlan = 0
       SET @n_CountOrderGroup = 0

      IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                  WHERE UserDefine09  = @c_WaveKey
                  AND Type = 'N' )
      BEGIN


         SELECT @n_CountLoadPlan = Count(Distinct LoadKey )
         FROM dbo.Orders WITH (NOLOCK)
         WHERE UserDefine09 = @c_WaveKey
         AND StorerKey = @c_StorerKey


         SELECT @n_CountOrderGroup = Count(1) FROM  (
            SELECT OrderGroup, SectionKey
            FROM dbo.Orders WITH (NOLOCK)
            WHERE UserDefine09 = @c_WaveKey
            AND StorerKey = @c_StorerKey
            Group By OrderGroup, SectionKey) A

         IF @n_CountLoadPlan <> @n_CountOrderGroup
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Order Type and LoadPlan Not Match. (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END
      END
      ELSE IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                       WHERE UserDefine09  = @c_WaveKey
                       AND Type = 'DctoDc' )
      BEGIN
         SELECT @n_CountLoadPlan = Count(Distinct LoadKey )
         FROM dbo.Orders WITH (NOLOCK)
         WHERE UserDefine09 = @c_WaveKey
         AND StorerKey = @c_StorerKey

         IF @n_CountLoadPlan <> 1
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81021   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+ ': Order Type and LoadPlan Not Match. (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END

         -- (ChewKP04) for DcToDc 1 Wave cannot have multiple orders with same SKU
         IF EXISTS ( SELECT OD.SKU , COUNT(DISTINCT OD.OrderKey) FROM dbo.OrderDetail OD WITH (NOLOCK)
                     INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKEy = OD.OrderKey
                     WHERE O.UserDefine09 = @c_WaveKey
                     GROUP BY OD.SKU
                     HAVING COUNT(DISTINCT OD.OrderKey) > 1 )
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81022  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
    SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+ ': 1 SKU Multiple OrderKey. (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END

      END
   END

   -----Create LOC BY ID data temporary table for full/partial pallet picking checking (FP/PP)
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderType = 'PTS'
   BEGIN
      SELECT LLI.Storerkey, LLI.Loc, LLI.ID, SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS QtyAvailable,
            (SELECT TOP 1 Qty FROM UCC WITH (NOLOCK)
              WHERE LLI.Storerkey = UCC.Storerkey AND LLI.Loc = UCC.Loc AND LLI.Id = UCC.Id AND UCC.Status='1') AS UCCQty
      INTO #TMP_LOCXID
      FROM LOTXLOCXID LLI WITH (NOLOCK)
      JOIN LOC            WITH (NOLOCK) ON LLI.Loc = LOC.Loc
      JOIN SKUXLOC SL     WITH (NOLOCK) ON LLI.Storerkey = SL.Storerkey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
      WHERE LLI.Storerkey = @c_Storerkey
      AND LLI.Qty > 0
      AND SL.LocationType NOT IN('PICK','CASE')
      AND LOC.LocationType <> 'DYNPICKP'
      AND LOC.LocationType <> (CASE WHEN @c_OrderType = 'DTC' THEN 'DYNPPICK' ELSE '*IGNORE*' END) --Launch ord will replen from DPP to DP
      GROUP BY LLI.Storerkey, LLI.Loc, LLI.ID

      SELECT PD.Storerkey, PD.Loc, PD.ID,
            CASE WHEN LI.QtyAvailable < ISNULL(LI.UCCQty,0) AND LOC.LocationType <> 'DYNPPICK' AND LOC.LocationHandling = '1' THEN
                 -- loose allocation of last carton of the pallet will be full carton picked by RDT, so qtyavailable will be zero
                 -- for bulk pallet location only.
                   0
            ELSE LI.QtyAvailable END AS LOCXID_QTYAVAILABLE,
            COUNT(DISTINCT PD.SKU) AS SkuCount, COUNT(DISTINCT PD.LOT) AS LotCount
      INTO #LOCXID_QTYAVAILABLE
      FROM WAVEDETAIL  WD WITH (NOLOCK)
      JOIN PICKDETAIL  PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
      JOIN #TMP_LOCXID LI WITH (NOLOCK) ON PD.Storerkey = LI.Storerkey AND PD.Loc = LI.Loc AND PD.Id = LI.Id
      JOIN LOC WITH (NOLOCK) ON PD.Loc = LOC.Loc
      JOIN SKUXLOC SL WITH (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
      WHERE WD.Wavekey = @c_Wavekey
      AND LOC.LocationType <> 'DYNPICKP'
      AND LOC.LocationType <> (CASE WHEN @c_OrderType = 'DTC' THEN 'DYNPPICK' ELSE '*IGNORE*' END) --Launch ord will replen from DPP to DP
       AND SL.LocationType NOT IN('PICK','CASE')
      GROUP BY PD.Storerkey, PD.Loc, PD.ID,
               CASE WHEN LI.QtyAvailable < ISNULL(LI.UCCQty,0) AND LOC.LocationType <> 'DYNPPICK' AND LOC.LocationHandling = '1' THEN
                    0
               ELSE LI.QtyAvailable END
   END

   BEGIN TRAN

   --Remove taskdetailkey and add wavekey from pickdetail of the wave
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
        -- tlting01
        SET @c_curPickdetailkey = ''
         DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT P.PickDetailKey
            FROM PickDetail P WITH (NOLOCK)
            JOIN WaveDetail W WITH (NOLOCK)
            ON (P.OrderKey = W.OrderKey)
            WHERE W.Wavekey = @c_Wavekey

         OPEN Orders_Pickdet_cur
         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey
         WHILE @@FETCH_STATUS = 0
         BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
                SET PICKDETAIL.TaskdetailKey = ''
                  , PICKDETAIL.Wavekey = @c_Wavekey
                  , EditWho    = SUSER_NAME()
                  , EditDate   = GETDATE()
                  , TrafficCop = NULL
                WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  CLOSE Orders_Pickdet_cur
                  DEALLOCATE Orders_Pickdet_cur
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 81004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                  GOTO RETURN_SP
               END
            FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey
         END
         CLOSE Orders_Pickdet_cur
         DEALLOCATE Orders_Pickdet_cur
   END



   --Create Temporary Tables
   --(Wan03) - START
   IF (@n_continue = 1 OR @n_continue = 2)  AND @c_OrderType = 'DTC'
   BEGIN
      CREATE TABLE  #Orders (
          RowRef    BIGINT IDENTITY(1,1) Primary Key,
          OrderKey  NVARCHAR(10)
         ,SKUCount  INT
         ,TotalPick INT
         )

   END
   --(Wan03) - END
   -----Retail Order Initialization and Validation-----

   IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderType = 'PTS'
   BEGIN
      IF EXISTS (SELECT 1
                 FROM WAVEDETAIL    WD WITH (NOLOCK)
                 JOIN ORDERS        OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
                 LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'WCSROUTE')
                                                     AND(CL.Code = CASE WHEN OH.Type <> 'N'
                                                                        THEN 'OTHERS'
                                                                        ELSE OH.OrderGroup + OH.SectionKey
                                                                        END)
                 LEFT JOIN LOC      L  WITH (NOLOCK) ON (CL.Short = L.Loc)
                 WHERE WD.Wavekey = @c_Wavekey
                 AND  (CL.Code IS NULL  OR L.Loc IS NULL))

      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Retail Order Zone not setup in ''Codelkup'' OR ''Loc'' table! (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END

      IF EXISTS (SELECT 1
                 FROM WAVEDETAIL            WD  WITH (NOLOCK)
                 JOIN ORDERS                OH  WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
                 JOIN ORDERDETAIL           OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
                 LEFT JOIN STORETOLOCDETAIL STL WITH (NOLOCK) ON (STL.Consigneekey = OD.UserDefine02)
                                                              AND(STL.StoreGroup = CASE WHEN OH.Type <> 'N'
                                                                                        THEN 'OTHERS'
                                                                                        ELSE OH.OrderGroup + OH.SectionKey
                                                                                        END)
                 LEFT JOIN LOC              L   WITH (NOLOCK) ON (STL.Loc = L.Loc)
                 WHERE WD.Wavekey = @c_Wavekey
                 AND  (STL.Loc IS NULL OR L.Loc IS NULL))

      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81006   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Put to Store Loc not setup in ''StorToLocDetail'' OR ''Loc'' table! (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END

      EXEC nspGetRight
               @c_Facility
            ,  @c_StorerKey
            ,  ''
            ,  'WCS'
            ,  @b_Success     OUTPUT
            ,  @c_WCS         OUTPUT
            ,  @n_err         OUTPUT
            ,  @c_errmsg      OUTPUT

      IF @b_Success = 0
      BEGIN
      SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81007   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getting Storer Configkey ''WCS''! (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO RETURN_SP
      END

      -----Generate PTS/RETAIL Order Tasks-----
      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         DECLARE cur_Retail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.Storerkey
              , PD.Sku
              , PD.Lot
              , PD.Loc
              , PD.ID
              , SUM(PD.Qty)
              , CASE WHEN ISNULL(LI.LOCXID_QTYAVAILABLE,0) <= 0 AND LOC.LocationHandling = '1' AND LOC.LocationType <> 'DYNPPICK'  --Bulk & Pallet handling loc only
                          AND LI.SkuCount = 1 AND LI.LotCount = 1
                     THEN 'FP'
                     WHEN OH.TYPE ='DCTODC' AND LOC.LocationType = 'DYNPPICK'
                     THEN 'STOTE'
                     ELSE 'PP' END AS PickMethod
              , SKU.Packkey
              , MIN(PD.UOM)
              , Consigneekey = CASE WHEN LOC.LocationType = 'DYNPPICK' THEN ISNULL(RTRIM(OD.Userdefine02),'') ELSE '' END
              , CASE WHEN OH.Type <> 'N'
                     THEN 'OTHERS'
                     ELSE ISNULL(RTRIM(OH.OrderGroup),'') + ISNULL(RTRIM(OH.SectionKey),'')
                     END
              , PD.DropID
         FROM WAVEDETAIL  WD          WITH (NOLOCK)
         JOIN ORDERS      OH          WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
         JOIN ORDERDETAIL OD          WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey
         JOIN PICKDETAIL  PD          WITH (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
         JOIN #LOCXID_QTYAVAILABLE LI WITH (NOLOCK) ON PD.Storerkey = LI.Storerkey AND PD.Loc = LI.Loc AND PD.Id = LI.Id
         JOIN LOC                     WITH (NOLOCK) ON PD.Loc = LOC.Loc
         JOIN SKU                     WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
         WHERE WD.Wavekey = @c_Wavekey
         GROUP BY PD.Storerkey
                , PD.Sku
                , PD.Lot
                , PD.Loc
                , PD.Id
                , PD.DropID  -- (Shong001)
                , OH.TYPE
                , LI.LOCXID_QTYAVAILABLE
                , LOC.LocationHandling
                , SKU.Packkey
                , LOC.LocationType
                , LI.SkuCount
                , LI.LotCount
                , CASE WHEN LOC.LocationType = 'DYNPPICK' THEN ISNULL(RTRIM(OD.Userdefine02),'') ELSE '' END
                , CASE WHEN OH.Type <> 'N'
                       THEN 'OTHERS'
                       ELSE ISNULL(RTRIM(OH.OrderGroup),'') + ISNULL(RTRIM(OH.SectionKey),'')
                       END
         ORDER BY PD.Storerkey, PD.Sku

         OPEN cur_Retail
         FETCH NEXT FROM cur_Retail INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @c_Packkey
                                       , @c_UOM, @c_Consigneekey,  @c_PickToZone, @c_PDet_DropID

         SET @c_SourceType = 'ispRLWAV02-RETAIL'
         -- Assign Dynamic pick loc and Create Replenishment tasks
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @n_UCCQty = 0
            SET @n_QtyPA  = 0

            IF ISNULL(RTRIM(@c_PDet_DropID), '') <> ''
            BEGIN
               SELECT TOP 1 @n_UCCQty = ISNULL(Qty,0)
               FROM UCC WITH (NOLOCK)
               WHERE Lot = @c_Lot
               AND   Loc = @c_FromLoc
               AND   Id  = @c_ID
               AND   Status = '1'
               AND  UCCNo = @c_PDet_DropID
            END

            IF ISNULL(@n_UCCQty,0) = 0
            BEGIN
               SELECT TOP 1 @n_UCCQty = ISNULL(Qty,0)
      FROM UCC WITH (NOLOCK)
               WHERE Lot = @c_Lot
               AND   Loc = @c_FromLoc
               AND   Id  = @c_ID
               AND   Status = '1'
            END

--            IF @c_UOM = '7' AND @n_UCCQty > 0 AND (@n_Qty % @n_UCCQty) > 0
--            BEGIN
--               SET @n_QtyPA = @n_UCCQty - (@n_Qty % @n_UCCQty)
--            END

            IF @c_Consigneekey = ''  -- If Pick from DPP, tasktype = 'SPK' else 'RPF'
            BEGIN
               SET @c_tasktype = 'RPF'
            END
            ELSE
            BEGIN
               SET @c_tasktype = 'SPK'
            END
            --(Wan03) - START
            --SET @c_LogicalFromLoc = ''
            --SELECT TOP 1 @c_AreaKey = AreaKey
            --           , @c_LogicalFromLoc = ISNULL(RTRIM(LogicalLocation),'')
            --FROM LOC        LOC WITH (NOLOCK)
            --JOIN AREADETAIL ARD WITH (NOLOCK) ON (LOC.PutawayZone = ARD.PutawayZone)
            --WHERE LOC.Loc = @c_FromLoc

            --SET @c_ToLoc = ''

            --IF @c_WCS = '1' OR  EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_WCS) AND type = 'P')
            --BEGIN
            --   SET @c_PickToZone = 'WCS'
            --END

            --IF ISNULL(RTRIM(@c_ToLoc),'') = ''
            --BEGIN
            --   SELECT @c_ToLoc = ISNULL(RTRIM(CL.Short),'')
            --   FROM CODELKUP CL WITH (NOLOCK)
            --   WHERE CL.ListName = 'WCSROUTE'
            --     AND CL.CODE = @c_PickToZone
            --END

            --SET @c_LogicalToLoc = ''
            --SELECT @c_LogicalToLoc = ISNULL(RTRIM(LogicalLocation),'')
            --FROM LOC WITH (NOLOCK)
            --WHERE Loc = @c_ToLoc
            --(Wan03) - END
            SET @c_OrderGroupSectionKey = @c_PickToZone --(JH01)
            SET @c_Message03 = @c_Consigneekey
            SET @c_Priority  = '3'                       --(Wan04)
            GOTO RELEASE_PK_TASKS
            RETAIL:

            FETCH NEXT FROM cur_Retail INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_PickMethod, @c_Packkey
                                          , @c_UOM, @c_Consigneekey,  @c_PickToZone, @c_PDet_DropID

         END
         CLOSE cur_Retail
         DEALLOCATE cur_Retail
      END
   END

   -----Generate DTC/ECOM Order Tasks-----
   --(Wan03) - START
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderType = 'DTC'
   BEGIN
      INSERT INTO #ORDERS (PD.Orderkey, SkuCount, TotalPick)
      SELECT PD.Orderkey
            ,SkuCount = Count(DISTINCT PD.Sku)
            ,TotalPick= SUM(PD.Qty)
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
      JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
      WHERE WD.Wavekey  = @c_Wavekey
      AND   OH.Type= 'DTC'
      GROUP BY PD.Orderkey

      -- Retrieve SINGLES & MULTI
      DECLARE CUR_ECOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.Storerkey
           , PD.Sku
           , PD.Lot
           , PD.Loc
           , PD.ID
           , SUM(PD.Qty)
           , CASE WHEN TMP.SKUCount = 1 AND TMP.TotalPick = 1 THEN 'SINGLES' ELSE 'MULTIS' END  -- (ChewKP05)
           , Orderkey = CASE WHEN TMP.SKUCount = 1 AND TMP.TotalPick = 1 THEN '' ELSE PD.Orderkey END
      FROM #ORDERS TMP
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TMP.Orderkey = PD.Orderkey)
      JOIN LOC        LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
      WHERE PD.Status = '0'
      AND  LOC.LocationType = 'DYNPPICK'
      GROUP BY CASE WHEN TMP.SKUCount = 1 AND TMP.TotalPick = 1 THEN '' ELSE PD.Orderkey END
              , PD.Storerkey
              , PD.Sku
              , PD.Lot
              , PD.Loc
              , PD.ID
              , CASE WHEN TMP.SKUCount = 1 AND TMP.TotalPick = 1 THEN 'SINGLES' ELSE 'MULTIS' END    -- (ChewKP05)
      ORDER BY Orderkey
            ,  PD.Loc
            ,  PD.Sku

      OPEN CUR_ECOM
      FETCH NEXT FROM CUR_ECOM INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty
                                  , @c_PickMethod, @c_Orderkey

      SET @c_SourceType = 'ispRLWAV02-ECOM'
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_tasktype = 'PK'
         SET @c_PickToZone = @c_PickMethod
         SET @c_UOM = ''
         SET @n_UCCQty = 0
         SET @c_Message03 = ''
         SET @c_PDet_DropID = ''

         GOTO RELEASE_PK_TASKS
         ECOM:
         FETCH NEXT FROM CUR_ECOM INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty
                                     , @c_PickMethod, @c_Orderkey
      END --Fetch
      CLOSE CUR_ECOM
      DEALLOCATE CUR_ECOM

   END
   --(Wan03) - END
   -----Generate Pickslip No-------

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE CUR_PS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT
          OrderKey = CASE WHEN @c_OrderType = 'DTC' THEN LPD.Orderkey ELSE '' END
         ,LoadKey  = LPD.LoadKey --CASE WHEN @c_OrderType = 'PTS' THEN LPD.LoadKey  ELSE '' END --(Wan01)
      FROM WAVEDETAIL      WD  WITH (NOLOCK)
      JOIN LOADPLANDETAIL  LPD WITH (NOLOCK) ON (WD.Orderkey = LPD.Orderkey)
      WHERE  WD.Wavekey = @c_wavekey

      OPEN CUR_PS

      FETCH NEXT FROM CUR_PS INTO @c_Orderkey, @c_LoadKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_PickZone = CASE WHEN @c_OrderKey = '' THEN 'LP' ELSE '8' END

         SET @c_PickSlipno = ''
         SELECT @c_PickSlipno = PickheaderKey
         FROM   PICKHEADER (NOLOCK)
         WHERE  Wavekey  = @c_Wavekey
         AND    OrderKey = @c_OrderKey
         AND    ExternOrderKey = @c_LoadKey
         AND    Zone =  @c_PickZone

         -- Create Pickheader
         IF ISNULL(@c_PickSlipno, '') = ''
         BEGIN
            EXECUTE nspg_GetKey
               'PICKSLIP'
            ,  9
            ,  @c_Pickslipno OUTPUT
            ,  @b_Success    OUTPUT
            ,  @n_err        OUTPUT
            ,  @c_errmsg     OUTPUT

            SET @c_Pickslipno = 'P' + @c_Pickslipno

            INSERT INTO PICKHEADER
                     (  PickHeaderKey
                     ,  Wavekey
                     ,  Orderkey
                     ,  ExternOrderkey
                     ,  Loadkey
                     ,  PickType
                     ,  Zone
                     ,  TrafficCop
                     )
            VALUES
                     (  @c_Pickslipno
                     ,  @c_Wavekey
                     ,  @c_OrderKey
                     ,  @c_Loadkey
                     ,  @c_Loadkey
                     ,  '0'
                     ,  @c_PickZone
                     ,  ''
                     )

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81008  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END
         END
         --(Wan01) - START
         -- IF print from Wave Pickslip, and later release wave, need to make sure refkeylookup record
         -- is sync with pickdetail record, hence delete and regenerate refkeylookup again
         IF EXISTS (SELECT 1 FROM REFKEYLOOKUP WITH (NOLOCK)
                    WHERE PickSlipNo = @c_PickSlipNo
                    AND   Loadkey    = @c_Loadkey)
            AND @c_Orderkey = ''                      --(Wan03)
         BEGIN
            DELETE FROM REFKEYLOOKUP WITH (ROWLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            AND   Loadkey    = @c_Loadkey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81017 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': DELETE REFKEYLOOKUP Failed (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END
         END
         --(Wan01) - END

        -- tlting01
        SET @c_curPickdetailkey = ''

         IF @c_Orderkey <> ''
         BEGIN
            DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT Pickdetailkey
               FROM PICKDETAIL WITH (NOLOCK)
               WHERE  OrderKey = @c_OrderKey
         END
         ELSE
         BEGIN
            DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.Pickdetailkey
            FROM ORDERS     OH WITH (NOLOCK)
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
            WHERE  OH.Loadkey = @c_Loadkey
         END

         OPEN Orders_Pickdet_cur
         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey
         WHILE @@FETCH_STATUS = 0 AND (@n_continue = 1 or @n_continue = 2)
         BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET  PickSlipNo = @c_PickSlipNo
                   ,EditWho = SUSER_NAME()
                   ,EditDate= GETDATE()
                   ,TrafficCop = NULL
                WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  CLOSE Orders_Pickdet_cur
                  DEALLOCATE Orders_Pickdet_cur
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               END
            FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey
         END
         CLOSE Orders_Pickdet_cur
         DEALLOCATE Orders_Pickdet_cur


 /*
         IF @c_Orderkey <> ''
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET  PickSlipNo = @c_PickSlipNo
                ,EditWho = SUSER_NAME()
                ,EditDate= GETDATE()
                ,TrafficCop = NULL
            WHERE  OrderKey = @c_OrderKey
         END
         ELSE
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET  PickSlipNo = @c_PickSlipNo
                ,EditWho = SUSER_NAME()
                ,EditDate= GETDATE()
                ,TrafficCop = NULL
            FROM ORDERS     OH WITH (NOLOCK)
            JOIN PICKDETAIL PD ON (OH.Orderkey = PD.Orderkey)
            WHERE  OH.Loadkey = @c_Loadkey
         END

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         END
    */
         IF NOT EXISTS (SELECT 1 FROM REFKEYLOOKUP WITH (NOLOCK)
                        WHERE PickSlipNo = @c_PickSlipNo
                        AND   Loadkey    = @c_Loadkey)
            AND @c_OrderKey = ''                      --(Wan03)
         BEGIN
            INSERT INTO REFKEYLOOKUP
                     (  PickDetailkey
                     ,  Orderkey
                     ,  OrderLineNumber
                     ,  Loadkey
                     ,  PickSlipNo
                     )
            SELECT   PD.PickDetailKey
                  ,  PD.Orderkey
                  ,  PD.OrderLineNumber
                  ,  @c_Loadkey
                  ,  @c_PickSlipNo
            FROM ORDERS     OH WITH (NOLOCK)
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
            WHERE  OH.Loadkey = @c_Loadkey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert REFKEYLOOKUP Failed (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END
         END

         IF NOT EXISTS (SELECT 1 FROM PICKINGINFO WITH (NOLOCK)
                        WHERE PickSlipNo = @c_PickSlipNo)
         BEGIN
            INSERT INTO PICKINGINFO (PickSlipNo, ScanIndate, PickerID)
            VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME())

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81011 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKINGINFO Failed (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END
         END

         FETCH NEXT FROM CUR_PS INTO @c_Orderkey, @c_LoadKey
      END
      CLOSE CUR_PS
      DEALLOCATE CUR_PS
   END

   -----Update Wave Status-----
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      UPDATE WAVE WITH (ROWLOCK)
          --SET STATUS = '1' -- Released        --(Wan01)
          --, EditWho = SUSER_NAME()            --(Wan01)
          SET TMReleaseFlag = 'Y'               --(Wan01) 
           ,  TrafficCop = NULL                 --(Wan01) 
           ,  EditWho = SUSER_SNAME()           --(Wan01) 
           ,  EditDate= GETDATE()               
      WHERE WAVEKEY = @c_wavekey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
        SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81012   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      END
   END

   -- Make sure all pickdetail have taskdetailkey stamped (Chee01)
   IF EXISTS ( SELECT 1
               FROM WAVEDETAIL WD  WITH (NOLOCK)
               JOIN PICKDETAIL PD  WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)
               WHERE WD.Wavekey = @c_Wavekey
                 AND ISNULL(PD.Taskdetailkey,'') = ''
                 AND PD.Storerkey = @c_Storerkey )
   BEGIN
      SET @n_continue = 3
      SET @n_err = 81018
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': TaskDetailkey not updated to pickdetail. (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      GOTO RETURN_SP
   END

    IF ( SELECT COUNT(1) FROM PICKHEADER PH WITH (NOLOCK) -- IN00245886
         WHERE PH.Wavekey = @c_Wavekey ) = 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @n_err = 81336
       SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Missing pickslip for Wave ' + ISNULL(RTRIM(@c_Wavekey),'') + '. (ispRLWAV02)'
       GOTO RETURN_SP
    END


   RETURN_SP:

   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'ispRLWAV02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

   RELEASE_PK_TASKS:

   --function to insert taskdetail
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      --(Wan03) - START
      SET @c_LogicalFromLoc = ''
      SELECT TOP 1 @c_AreaKey = AreaKey
                 , @c_LogicalFromLoc = ISNULL(RTRIM(LogicalLocation),'')
      FROM LOC        LOC WITH (NOLOCK)
      JOIN AREADETAIL ARD WITH (NOLOCK) ON (LOC.PutawayZone = ARD.PutawayZone)
      WHERE LOC.Loc = @c_FromLoc

      SET @c_ToLoc = ''

      IF @c_OrderType = 'PTS'
      BEGIN
         IF @c_WCS = '1' OR  EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_WCS) AND type = 'P')
         BEGIN
            SET @c_PickToZone = 'WCS'
     END
      END

      IF ISNULL(RTRIM(@c_ToLoc),'') = ''
      BEGIN
         SELECT @c_ToLoc = ISNULL(RTRIM(CL.Short),'')
         FROM CODELKUP CL WITH (NOLOCK)
         WHERE CL.ListName = 'WCSROUTE'
           AND CL.CODE = @c_PickToZone
      END

      SET @c_LogicalToLoc = ''
      SELECT @c_LogicalToLoc = ISNULL(RTRIM(LogicalLocation),'')
      FROM LOC WITH (NOLOCK)
      WHERE Loc = @c_ToLoc

      IF @c_OrderType = 'DTC' --(JH01) ADD IF 
      BEGIN
         SET @c_LoadKey = ''
         SELECT Top 1 @c_LoadKey = O.LoadKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK)  ON O.OrderKEy = PD.OrderKey
         WHERE PD.WaveKey = @c_WaveKey
         AND PD.Status = '0'
         AND PD.SKU = @c_SKU
         AND PD.Lot = @c_Lot
         AND PD.Loc = @c_FromLoc
         AND PD.ID  = @c_ID      
      END

      IF @c_OrderType = 'PTS'  --(JH01) START
      BEGIN
         SET @c_LoadKey = ''
         SELECT Top 1 @c_LoadKey = O.LoadKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK)  ON O.OrderKEy = PD.OrderKey
         WHERE PD.WaveKey = @c_WaveKey
         AND PD.Status = '0'
         AND PD.SKU = @c_SKU
         AND PD.Lot = @c_Lot
         AND PD.Loc = @c_FromLoc
         AND PD.ID  = @c_ID
         AND @c_OrderGroupSectionKey = CASE WHEN O.Type <> 'N'
                        THEN 'OTHERS'
                        ELSE ISNULL(RTRIM(O.OrderGroup),'') + ISNULL(RTRIM(O.SectionKey),'')
                        END  
      END --(JH01) END
      
      --(Wan03) - END
      SET @b_success = 1
      EXECUTE   nspg_getkey
               'TaskDetailKey'
              , 10
              , @c_taskdetailkey OUTPUT
              , @b_success       OUTPUT
              , @n_err           OUTPUT
              , @c_errmsg        OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SET @n_continue = 3
         GOTO RETURN_SP
      END

      IF @b_success = 1
      BEGIN
         INSERT TASKDETAIL
         (
         TaskDetailKey
         ,TaskType
         ,Storerkey
         ,Sku
         ,UOM
         ,UOMQty
         ,Qty
         ,SystemQty
         ,Lot
         ,FromLoc
         ,FromID
         ,ToLoc
         ,ToID
         ,SourceType
         ,SourceKey
         ,Priority
         ,SourcePriority
         ,Status
         ,LogicalFromLoc
         ,LogicalToLoc
         ,PickMethod
         ,Wavekey
         ,Listkey
         ,Areakey
         ,Message03
         ,CaseID -- (ChewKP01)
         ,LoadKey
         ,OrderKey -- (ChewKP05)
         )
         VALUES
         (
         @c_taskdetailkey
         ,@c_TaskType --Tasktype
         ,@c_Storerkey
         ,@c_Sku
         ,@c_UOM -- UOM,
         ,@n_UCCQty  -- UOMQty,
         ,@n_Qty
         ,@n_Qty  --systemqty
         ,@c_Lot
         ,@c_fromloc
         ,@c_ID -- from id
         ,@c_toloc
         ,@c_ID -- to id
         ,@c_SourceType --Sourcetype
         ,@c_Wavekey    --Sourcekey
         ,@c_Priority   -- Priority          --(Wan04)
         ,'9' -- Sourcepriority
         ,'0' -- Status
         ,@c_LogicalFromLoc --Logical from loc
         ,@c_LogicalToLoc   --Logical to loc
         ,@c_PickMethod
         ,@c_Wavekey
         ,''
         ,@c_Areakey
         ,@c_Message03
         ,CASE WHEN @c_PDet_DropID <> '' THEN @c_PDet_DropID ELSE '' END -- (ChewKP01)
         ,@c_LoadKey
         ,@c_Orderkey                                                    -- (ChewKP05)
         )

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN

            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81013   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '

            GOTO RETURN_SP
         END
      END
   END

   --Update taskdetailkey/wavekey to pickdetail
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderType = 'DTC'  --(JH01) ADD 'AND @c_OrderType = 'DTC''
   BEGIN
      SET @n_ReplenQty = @n_Qty

      DECLARE CUR_PICKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickdetailKey
            ,PD.Qty
            ,ISNULL(RTRIM(PD.Dropid),'')
      FROM WAVEDETAIL WD  WITH (NOLOCK)
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (PD.Orderkey = OD.Orderkey) AND (PD.OrderLineNumber = OD.OrderLineNumber)
      WHERE WD.Wavekey = @c_Wavekey
      AND ISNULL(PD.Taskdetailkey,'') = ''
      AND PD.Storerkey = @c_Storerkey
      AND PD.Sku = @c_sku
      AND PD.Lot = @c_Lot
      AND PD.Loc = @c_FromLoc
      AND PD.ID  = @c_ID
      AND PD.Orderkey = CASE WHEN @c_Ordertype = 'PTS' OR @c_Orderkey = '' THEN PD.Orderkey ELSE @c_Orderkey END --(Wan03)
      AND OD.UserDefine02 = CASE WHEN @c_Ordertype = 'PTS' AND @c_TaskType = 'SPK' THEN @c_Consigneekey ELSE OD.UserDefine02 END -- (ChewKPXX) --(Wan03)
      AND PD.DropID = CASE WHEN ISNULL(@c_PDet_DropID, '') = '' THEN PD.DropID ELSE @c_PDet_DropID END -- (Shong001)
      ORDER BY PD.PickDetailKey

      OPEN CUR_PICKD

      FETCH NEXT FROM CUR_PICKD INTO @c_PickdetailKey
                                    ,@n_PickQty
                                    ,@c_DropId
      WHILE @@FETCH_STATUS <> -1 AND @n_ReplenQty > 0
      BEGIN
         IF @c_Ordertype = 'PTS' AND ((@c_TaskType = 'RPF' AND @c_DropID = '') OR   --(Wan03)
            (@c_TaskType = 'SPK' AND @c_DropID <>''))
         BEGIN
            GOTO NEXT_PD
         END

         IF  @c_TaskType = 'PK' AND @c_Orderkey = ''
             IF NOT EXISTS ( SELECT 1
                             FROM PICKDETAIL PD WITH (NOLOCK)
                             JOIN #ORDERS    OH ON (PD.Orderkey = OH.Orderkey )
                             WHERE PD.Pickdetailkey = @c_PickdetailKey
                             AND  OH.SkuCount = 1
                             AND  OH.TotalPick= 1 )
         BEGIN
            BEGIN
               GOTO NEXT_PD
            END
         END

         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET Taskdetailkey = @c_TaskdetailKey
            ,EditWho = SUSER_NAME()
            ,EditDate= GETDATE()
            ,TrafficCop = NULL
         WHERE Pickdetailkey = @c_PickdetailKey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81016
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            BREAK
         END

         SET @n_ReplenQty = @n_ReplenQty - @n_PickQty
         NEXT_PD:
         FETCH NEXT FROM CUR_PICKD INTO @c_PickdetailKey
                                       ,@n_PickQty
                                       ,@c_DropID
      END
      CLOSE CUR_PICKD
      DEALLOCATE CUR_PICKD
   END
   
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_OrderType = 'PTS'  --(JH01) START
   BEGIN
      SET @n_ReplenQty = @n_Qty

      --INSERT INTO TraceInfo ( TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5 )
      --VALUES ( 'ispRLWAV02', GETDATE(), 'PTS', @c_sku, @c_Lot, @c_FromLoc, @c_ID, @c_Orderkey, @c_Ordertype, @c_TaskType, @c_PDet_DropID, @c_PickToZone )

      DECLARE CUR_PICKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickdetailKey
            ,PD.Qty
            ,ISNULL(RTRIM(PD.Dropid),'')
      FROM WAVEDETAIL WD  WITH (NOLOCK)
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (WD.Orderkey = PD.Orderkey)
      JOIN ORDERS      OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey   --(JH01)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (PD.Orderkey = OD.Orderkey) AND (PD.OrderLineNumber = OD.OrderLineNumber)
      WHERE WD.Wavekey = @c_Wavekey
      AND ISNULL(PD.Taskdetailkey,'') = ''
      AND PD.Storerkey = @c_Storerkey
      AND PD.Sku = @c_sku
      AND PD.Lot = @c_Lot
      AND PD.Loc = @c_FromLoc
      AND PD.ID  = @c_ID
      AND PD.Orderkey = CASE WHEN @c_Ordertype = 'PTS' OR @c_Orderkey = '' THEN PD.Orderkey ELSE @c_Orderkey END --(Wan03)
      AND OD.UserDefine02 = CASE WHEN @c_Ordertype = 'PTS' AND @c_TaskType = 'SPK' THEN @c_Consigneekey ELSE OD.UserDefine02 END -- (ChewKPXX) --(Wan03)
      AND PD.DropID = CASE WHEN ISNULL(@c_PDet_DropID, '') = '' THEN PD.DropID ELSE @c_PDet_DropID END -- (Shong001)
      AND @c_OrderGroupSectionKey = CASE WHEN OH.Type <> 'N'  --(JH01)
                     THEN 'OTHERS'
                     ELSE ISNULL(RTRIM(OH.OrderGroup),'') + ISNULL(RTRIM(OH.SectionKey),'')
                     END  --(JH01)
      ORDER BY PD.PickDetailKey

      OPEN CUR_PICKD

      FETCH NEXT FROM CUR_PICKD INTO @c_PickdetailKey
                                    ,@n_PickQty
                                    ,@c_DropId
      WHILE @@FETCH_STATUS <> -1 AND @n_ReplenQty > 0
      BEGIN
         IF @c_Ordertype = 'PTS' AND ((@c_TaskType = 'RPF' AND @c_DropID = '') OR   --(Wan03)
            (@c_TaskType = 'SPK' AND @c_DropID <>''))
         BEGIN
            GOTO NEXT_PD_PTS
         END

         IF  @c_TaskType = 'PK' AND @c_Orderkey = ''
             IF NOT EXISTS ( SELECT 1
                             FROM PICKDETAIL PD WITH (NOLOCK)
                             JOIN #ORDERS    OH ON (PD.Orderkey = OH.Orderkey )
                             WHERE PD.Pickdetailkey = @c_PickdetailKey
                             AND  OH.SkuCount = 1
                             AND  OH.TotalPick= 1 )
         BEGIN
            BEGIN
               GOTO NEXT_PD_PTS
            END
         END

         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET Taskdetailkey = @c_TaskdetailKey
            ,EditWho = SUSER_NAME()
            ,EditDate= GETDATE()
            ,TrafficCop = NULL
         WHERE Pickdetailkey = @c_PickdetailKey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81016
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            BREAK
         END

         SET @n_ReplenQty = @n_ReplenQty - @n_PickQty
         NEXT_PD_PTS:
         FETCH NEXT FROM CUR_PICKD INTO @c_PickdetailKey
                                       ,@n_PickQty
                                       ,@c_DropID
      END
      CLOSE CUR_PICKD
      DEALLOCATE CUR_PICKD
   END   --(JH01) END
   
   IF @c_OrderType = 'DTC'       --(Wan03)
      GOTO ECOM                  --(Wan03)
   IF @c_OrderType = 'PTS'
      GOTO RETAIL

END --sp end

GO