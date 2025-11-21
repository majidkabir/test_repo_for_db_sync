SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ReplenishmentRpt_PC31                             */
/* Creation Date:  06-JUL-2020                                             */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-13924 - [PH] Unilever TM Replenishment Task Generation     */
/*        : modify from isp_ReplenishmentRpt_PC27                          */
/*                                                                         */
/* Called By: Replenishment Report                                         */
/*                                                                         */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/* 29-Dec-2020 WLChooi  1.1   Fix wrong datawindow name for config (WL01)  */
/***************************************************************************/
CREATE PROC [dbo].[isp_ReplenishmentRpt_PC31]
               @c_zone01            NVARCHAR(10)
,              @c_zone02            NVARCHAR(10)
,              @c_zone03            NVARCHAR(10)
,              @c_zone04            NVARCHAR(10)
,              @c_zone05            NVARCHAR(10)
,              @c_zone06            NVARCHAR(10)
,              @c_zone07            NVARCHAR(10)
,              @c_zone08            NVARCHAR(10)
,              @c_zone09            NVARCHAR(10)
,              @c_zone10            NVARCHAR(500) --SKU                 
,              @c_zone11            NVARCHAR(500) --location Aisle     
,              @c_zone12            NVARCHAR(10)   --SKU.ABC
,              @c_storerkey         NVARCHAR(15)
,              @c_ReplGrp           NVARCHAR(30)     
,              @c_backendjob        NVARCHAR(10)= 'N'  
,              @c_Functype          NCHAR(1)    = ''  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE        @n_continue int          /* continuation flag
   1=Continue
   2=failed but continue processsing
   3=failed do not continue processing
   4=successful but skip furthur processing */
   DECLARE @b_debug              INT            = 0
         , @b_Success            INT            = 1
         , @n_Err                INT            = 0
         , @c_ErrMsg             NVARCHAR(255)  = ''
         , @c_Sql                NVARCHAR(4000) = ''

         , @c_priority           NVARCHAR(5)    = ''
         , @c_ReplLottable02     NVARCHAR(18)   = ''
         , @c_ReplenishmentGroup NVARCHAR(10)   = ''

         , @c_Packkey            NVARCHAR(10)   = ''
         , @c_UOM                NVARCHAR(10)   = ''
         , @c_ToLocationType     NVARCHAR(10)   = ''
         , @n_CaseCnt            FLOAT          = 0.00  
         , @n_Pallet             FLOAT          = 0.00
         
         , @n_FilterQty          INT            = 0  
         , @c_ReplFullPallet     NVARCHAR(10)   = 'N'
         , @c_Storerkey_CL       NVARCHAR(15)   = '' 
         , @c_ReplFreshStock     NVARCHAR(10)   = 'N'  
         , @c_SUSR2              NVARCHAR(18)   = '' 
         , @n_shelflife          INT            = 0  
         , @d_today              DATETIME  

         , @CUR_REPL             CURSOR


   DECLARE @c_sqlinsert        NVARCHAR(MAX)
        ,  @c_sqlselect        NVARCHAR(MAX)
        ,  @c_sqlfrom          NVARCHAR(MAX)
        ,  @c_sqlwhere         NVARCHAR(MAX) 
        ,  @c_condition1       NVARCHAR(MAX)
        ,  @c_condition2       NVARCHAR(MAX)
        ,  @c_sqlgrpby         NVARCHAR(MAX)
        ,  @c_ExecStatements   NVARCHAR(4000)  
        ,  @c_ExecArguments    NVARCHAR(4000) 
        ,  @c_LottableName     NVARCHAR(30)    
        ,  @c_LottableValue    NVARCHAR(30)    

   SET @n_continue=1
   SET @b_debug = 0
   SET @c_ReplenishmentGroup = ''  

   IF @c_zone11 = '1'
   BEGIN
      SET @b_debug = CAST( @c_zone11 AS int)
      SET @c_zone11 = ''
   END

   IF @c_FuncType IN ( 'P' )                                     
   BEGIN
      GOTO QUIT_SP    
   END

   IF OBJECT_ID('tempdb..#REPLENISHMENT','u') IS NOT NULL
   BEGIN
      DROP TABLE #REPLENISHMENT;
   END

   CREATE TABLE #REPLENISHMENT
      (     RowID                   INT   IDENTITY(1,1)  PRIMARY KEY
         ,  StorerKey               NVARCHAR(15)   NOT NULL DEFAULT('')
         ,  SKU                     NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  FromLOC                 NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  ToLOC                   NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  Lot                     NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  ID                      NVARCHAR(18)   NOT NULL DEFAULT('')
         ,  LocationType            NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  Qty                     INT            NOT NULL DEFAULT(0)
         ,  QtyMoved                INT            NOT NULL DEFAULT(0)
         ,  QtyInPickLOC            INT            NOT NULL DEFAULT(0)
         ,  [Priority]              NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  UOM                     NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  Packkey                 NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  ReplLottable02          NVARCHAR(18)   NOT NULL DEFAULT('')                  
      )

   --Delete Taskdetail
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_Taskdetailkey NVARCHAR(10) = ''

      DECLARE Cur_Taskdetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TD.Taskdetailkey
      FROM TASKDETAIL TD (NOLOCK) 
      JOIN LOC (NOLOCK) ON LOC.LOC = TD.FromLoc
      WHERE TD.TaskType = 'RPF' AND TD.[Status] = '0' AND (TD.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')       
      AND LOC.Facility = @c_zone01

      OPEN Cur_Taskdetail

      FETCH NEXT FROM Cur_Taskdetail INTO @c_Taskdetailkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM TaskDetail
         WHERE TaskDetailKey = @c_Taskdetailkey

         FETCH NEXT FROM Cur_Taskdetail INTO @c_Taskdetailkey
      END
   END

   --Delete Replenishment
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @c_Sourcekey1 NVARCHAR(10) = ''

      DECLARE CUR_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT R.REPLENISHMENTKEY
      FROM REPLENISHMENT R (NOLOCK)
      WHERE (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL') AND R.RefNo = 'PC29'
      
      OPEN CUR_REPLEN
      
      FETCH NEXT FROM CUR_REPLEN INTO @c_Sourcekey1
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE REPLENISHMENT
         SET Confirmed = 'N'
         WHERE REPLENISHMENTKEY = @c_Sourcekey1

         DELETE FROM REPLENISHMENT 
         WHERE REPLENISHMENTKEY = @c_Sourcekey1

         FETCH NEXT FROM CUR_REPLEN INTO @c_Sourcekey1
      END
      CLOSE CUR_REPLEN
      DEALLOCATE CUR_REPLEN
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @n_InvCnt                      INT
            , @c_CurrentStorer               NVARCHAR(15)
            , @c_CurrentSKU                  NVARCHAR(20)
            , @c_CurrentLoc                  NVARCHAR(10)
            , @c_CurrentPriority             NVARCHAR(5)
            , @n_Currentfullcase             INT
            , @n_CurrentSeverity             INT
            , @c_FromLOC                     NVARCHAR(10)
            , @c_Fromlot                     NVARCHAR(10)
            , @c_Fromid                      NVARCHAR(18)
            , @n_FromQty                     INT
            , @n_QtyAllocated                INT
            , @n_QtyPicked                   INT
            , @n_RemainingQty                INT
            , @n_numberofrecs                INT
            , @c_ReplenishmentKey            NVARCHAR(10)
            , @c_NoMixLottable02             NVARCHAR(10)
            , @c_Lottable02                  NVARCHAR(18)
            , @c_ReplValidationRules         NVARCHAR(10)
            , @c_CaseToPick                  NVARCHAR(10) 

      SET @c_CurrentStorer    = ''
      SET @c_CurrentSKU       = ''
      SET @c_CurrentLoc       = ''
      SET @c_CurrentPriority  = ''
      SET @n_currentfullcase  = 0
      SET @n_CurrentSeverity  = 9999999
      SET @n_FromQty          = 0
      SET @n_RemainingQty     = 0
      SET @n_numberofrecs     = 0

      SET @c_NoMixLottable02  = '0'
      SET @c_Lottable02       = '' 
      SET @c_condition1 = ''       
      SET @c_condition2 = ''      
      /* Make a temp version of SKUxLOC */

      IF OBJECT_ID('tempdb..#TempSKUxLOC','u') IS NOT NULL
      BEGIN
         DROP TABLE #TempSKUxLOC;
      END

      CREATE TABLE #TempSKUxLOC
         (     RowID                   INT   IDENTITY(1,1)  PRIMARY KEY
            ,  StorerKey               NVARCHAR(15)   NOT NULL DEFAULT('')
            ,  SKU                     NVARCHAR(20)   NOT NULL DEFAULT('')
            ,  LOC                     NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  LocationType            NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  ReplenishmentPriority   NVARCHAR(5)    NOT NULL DEFAULT('')
            ,  ReplenishmentSeverity   INT            NOT NULL DEFAULT(0)
            ,  ReplenishmentCasecnt    INT            NOT NULL DEFAULT(0)
            ,  Packkey                 NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  Susr2                   NVARCHAR(18)   NOT NULL DEFAULT('')
         )

      IF OBJECT_ID('tempdb..#WaveRepl','u') IS NOT NULL
      BEGIN
         DROP TABLE #WaveRepl;
      END

      CREATE TABLE #WaveRepl
         (     RowID                   INT   IDENTITY(1,1)  PRIMARY KEY
            ,  StorerKey               NVARCHAR(15)   NOT NULL DEFAULT('')
            ,  SKU                     NVARCHAR(20)   NOT NULL DEFAULT('')
            ,  ToLOC                   NVARCHAR(10)   NOT NULL DEFAULT('')
            ,  Qty                     INT            NOT NULL DEFAULT(0)
         )

      INSERT INTO #WaveRepl
         (     StorerKey              
            ,  SKU                    
            ,  Toloc
            ,  Qty
         )
      SELECT   StorerKey              
            ,  SKU                    
            ,  ToLoc 
            ,  ISNULL(SUM(Qty),0)
      FROM REPLENISHMENT RP WITH (NOLOCK)
      WHERE (RP.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')              
      AND   RP.Confirmed = 'N'   
      AND   RP.Wavekey <> '' 
      AND   RP.Wavekey IS NOT NULL
      GROUP BY StorerKey              
            ,  SKU                    
            ,  ToLoc                                  

      SELECT @c_sqlinsert = N'INSERT INTO #TempSKUxLOC '
                      + '(   StorerKey  '            
                      + '  ,  SKU   '                 
                      + '  ,  LOC  '                  
                      + '  ,  ReplenishmentPriority ' 
                      + '  ,  ReplenishmentSeverity'  
                      + '  ,  ReplenishmentCasecnt'  
                      + '  ,  LocationType'                 
                      + '  ,  Packkey  '              
                      + '  ,  Susr2  ) '
                       
     SELECT @c_sqlselect = N'SELECT SKUxLOC.StorerKey  '             
         + ',  SKUxLOC.SKU '
         + ',  SKUxLOC.LOC '
         --+ ',  SKUxLOC.ReplenishmentPriority '
         + ',  CASE WHEN ((SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) + ISNULL(R.Qty,0) < SKUxLOC.QtyLocationMinimum) THEN ''4'' '
         + '        WHEN ((SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) + ISNULL(R.Qty,0) = SKUxLOC.QtyLocationMinimum) THEN ''6'' '
         + '        WHEN ((SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) + ISNULL(R.Qty,0) > SKUxLOC.QtyLocationMinimum) THEN ''7'' '
         + '        ELSE SKUxLOC.ReplenishmentPriority END AS ReplenishmentPriority '
         + ',  ReplenishmentSeverity = SKUxLOC.QtyLocationLimit - ISNULL(SUM((LOTXLOCXID.Qty - LOTXLOCXID.QtyPicked) + LOTXLOCXID.PendingMoveIN),0) - ISNULL(R.Qty,0) '    --(Wan01)
         + ',  SKUxLOC.QtyLocationLimit '
         + ',  LOC.Locationtype '
         + ',  SKU.Packkey '
         + ',  Susr2 = ISNULL(SKU.SUSR2,'''')   ' + CHAR(13) 
     SELECT @c_sqlfrom = N' FROM SKUxLOC    WITH (NOLOCK) ' + CHAR(13)
      + ' JOIN LOC        WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc) ' + CHAR(13)
      + ' JOIN SKU        WITH (NOLOCK) ON (SKUxLOC.Storerkey = SKU.Storerkey AND SKUxLOC.Sku = SKU.Sku)' + CHAR(13)
      + ' LEFT JOIN LOTXLOCXID WITH (NOLOCK)  ON (SKUxLOC.Storerkey = LOTXLOCXID.Storerkey AND SKUxLOC.Sku = LOTXLOCXID.Sku AND SKUxLOC.Loc = LOTXLOCXID.Loc) '  + CHAR(13)
      + ' LEFT JOIN #WaveRepl R WITH (NOLOCK)ON (SKUxLOC.Storerkey = R.Storerkey AND SKUxLOC.Sku = R.Sku AND SKUxLOC.Loc = R.ToLoc)  '  + CHAR(13)                       --(Wan01)  

     SELECT @c_sqlwhere = N' WHERE (SKUxLOC.Storerkey = @c_Storerkey OR @c_Storerkey = ''ALL'')  ' + CHAR(13)  
      + ' AND   SKUxLOC.LOCationtype IN ( ''CASE'',''PALLET'',''PICK'') ' + CHAR(13)
      + ' AND   SKUxLOC.ReplenishmentCasecnt > 0 ' + CHAR(13)
      + ' AND   SKUxLOC.QtyExpected <= 0 ' + CHAR(13)
      --AND   SKUxLOC.Qty - SKUxLOC.QtyPicked <= SKUxLOC.QtyLocationMinimum                                                                             
      + 'AND   (LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09) ' + CHAR(13) --, @c_zone10, @c_zone11)       --(CS01)
      + 'OR    @c_zone02 = ''ALL'')'  + CHAR(13)
      + 'AND   LOC.FACILITY = @c_Zone01 ' + CHAR(13) 
      + 'AND  (LOC.PickZone= @c_ReplGrp OR @c_ReplGrp = ''ALL'')'  + CHAR(13)
      + 'AND   LOC.LocationFlag NOT IN (''HOLD'', ''DAMAGE'') ' + CHAR(13)
      + 'AND   LOC.Status <> ''HOLD'' ' + CHAR(13)
      + 'AND   (SKU.ABC = @c_Zone12 OR @c_Zone12 IN ( ''ALL'', '''')) ' + CHAR(13)

      SELECT @c_sqlgrpby = N' GROUP BY SKUxLOC.ReplenishmentPriority ' + CHAR(13)
               + ', SKUxLOC.StorerKey '
               + ', SKUxLOC.SKU'
               + ', SKUxLOC.LOC'
               + ', SKUxLOC.Qty'
               + ', SKUxLOC.QtyPicked'
               + ', SKUxLOC.QtyAllocated'
               + ', SKUxLOC.QtyLocationMinimum'
               + ', SKUxLOC.QtyLocationLimit'
               + ', LOC.Locationtype'
               + ', SKU.Packkey'
               + ', ISNULL(SKU.SUSR2,'''') '
               + ', ISNULL(R.Qty,0)   '  + CHAR(13)                                                                                                                          --(Wan01)
               --+ ' HAVING (SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) + ISNULL(R.Qty,0) <= SKUxLOC.QtyLocationMinimum    ' + CHAR(13)
               --+ ' HAVING ((SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) + ISNULL(R.Qty,0) < SKUxLOC.QtyLocationMinimum) OR ' + CHAR(13)
               --+ '        ((SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) + ISNULL(R.Qty,0) = SKUxLOC.QtyLocationMinimum) OR ' + CHAR(13)
               --+ '        ((SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) + ISNULL(R.Qty,0) > SKUxLOC.QtyLocationMinimum) OR ' + CHAR(13)
               + ' HAVING ((SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) + ISNULL(R.Qty,0) < SKUxLOC.QtyLocationMinimum) OR ' + CHAR(13)
               + '        ((SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) + ISNULL(R.Qty,0) = SKUxLOC.QtyLocationMinimum) OR ' + CHAR(13)
               + '        ((SKUxLOC.Qty - SKUxLOC.QtyPicked) + SUM(ISNULL(LOTXLOCXID.PendingMoveIN,0)) + ISNULL(R.Qty,0) > SKUxLOC.QtyLocationMinimum)    ' + CHAR(13)
               --+ '        (SKUxLOC.ReplenishmentPriority = ''9'') ' + CHAR(13)
               + ' ORDER  By SKUxLOC.StorerKey '
               +'         ,  SKUxLOC.SKU '
               +'         ,  SKUxLOC.LOC  '

      IF ISNULL(@c_zone10,'') <> ''
      BEGIN
         SELECT @c_condition1 = N' AND SKUxLOC.SKU IN (SELECT ColValue FROM dbo.fnc_DelimSplit('','',@c_zone10)) ' 
      END

      IF ISNULL(@c_zone11,'') <> ''
      BEGIN
         SELECT @c_condition2 = N' AND LOC.LocAisle IN (SELECT ColValue FROM dbo.fnc_DelimSplit('','',@c_zone11)) ' 
      END


      SET @c_SQL = @c_sqlinsert + CHAR(13) + @c_sqlselect + CHAR(13) + @c_sqlfrom + @c_sqlwhere + @c_condition1 + @c_condition2 + @c_sqlgrpby
      --PRINT @c_SQL

      SET @c_ExecArguments = N'@c_Storerkey        NVARCHAR(50)'  
                            +',@c_zone01           NVARCHAR(10) '
                            +',@c_zone02           NVARCHAR(10)' 
                            +',@c_zone03           NVARCHAR(10)' 
                            +',@c_zone04           NVARCHAR(10)' 
                            +',@c_zone05           NVARCHAR(10)' 
                            +',@c_zone06           NVARCHAR(10)' 
                            +',@c_zone07           NVARCHAR(10)' 
                            +',@c_zone08           NVARCHAR(10)' 
                            +',@c_zone09           NVARCHAR(10)' 
                            +',@c_zone10           NVARCHAR(4000)' 
                            +',@c_zone11           NVARCHAR(4000)' 
                            +',@c_zone12           NVARCHAR(10)'
                            +',@c_ReplGrp          NVARCHAR(30) '     
                                    
  
      EXEC sp_ExecuteSql @c_SQL   
                       , @c_ExecArguments  
                       , @c_Storerkey  
                       , @c_zone01
                       , @c_zone02
                       , @c_zone03
                       , @c_zone04
                       , @c_zone05
                       , @c_zone06
                       , @c_zone07
                       , @c_zone08
                       , @c_zone09
                       , @c_zone10
                       , @c_zone11
                       , @c_zone12
                       , @c_ReplGrp

               --SELECT @c_Sql
               --GOTO QUIT_SP
    
      IF @@ROWCOUNT > 0  AND ISNULL(@c_ReplGrp,'') IN ('ALL','')  
      BEGIN
         EXECUTE nspg_GetKey                                                     
            'REPLENGROUP',                                                       
            9,                                                                   
            @c_ReplenishmentGroup OUTPUT,                                        
            @b_success OUTPUT,                                                   
            @n_err OUTPUT,                                                       
            @c_errmsg OUTPUT                                                     
                                                                                 
            IF @b_success = 1                                                      
               SET @c_ReplenishmentGroup = 'T' + @c_ReplenishmentGroup           
            END
            ELSE
               SET @c_ReplenishmentGroup = @c_ReplGrp  

               IF @b_debug = 1
               BEGIN
                  SELECT * FROM #WaveRepl
               
                  SELECT CurrentStorer = StorerKey
                        ,CurrentSKU = SKU
                        ,CurrentLoc = LOC
                        ,CurrentSeverity        = ReplenishmentSeverity
                        ,ReplenishmentPriority  = ReplenishmentPriority
                        ,ToLocationType         = LocationType
                        ,Packkey    = Packkey
                        ,SUSR2      = SUSR2
                  FROM #TempSKUxLOC
               END

      /* Loop through SKUxLOC for the currentSKU, current storer */
      /* to pickup the next severity */
      DECLARE CUR_SKUxLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT CurrentStorer = StorerKey
            ,CurrentSKU = SKU
            ,CurrentLoc = LOC
            ,CurrentSeverity        = ReplenishmentSeverity
            ,ReplenishmentPriority  = ReplenishmentPriority
            ,ToLocationType         = LocationType
            ,Packkey    = Packkey
            ,SUSR2      = SUSR2
      FROM #TempSKUxLOC
      ORDER BY RowId

      OPEN CUR_SKUxLOC

      FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentStorer
                                    ,  @c_CurrentSKU
                                    ,  @c_CurrentLoc
                                    ,  @n_CurrentSeverity
                                    ,  @c_CurrentPriority
                                    ,  @c_ToLocationType
                                    ,  @c_Packkey
                                    ,  @c_SUSR2  
      WHILE @@Fetch_Status <> -1
      BEGIN

         /* We now have a pickLOCation that needs to be replenished! */
         /* Figure out which LOCations in the warehouse to pull this product from */
         /* End figure out which LOCations in the warehouse to pull this product from */
         SET @c_FromLOC = ''
         SET @c_FromLot = ''
         SET @c_FromId  = ''
         SET @n_FromQty = 0

         SET @n_RemainingQty  = @n_CurrentSeverity

         SET @n_Pallet = 0.00
         SET @n_CaseCnt = 0.00
         SELECT @n_Pallet = ISNULL(Pallet,0)
               ,@n_CaseCnt= ISNULL(CaseCnt,0)
               ,@c_UOM    = P.PackUOM3
         FROM PACK P WITH (NOLOCK) 
         WHERE P.Packkey = @c_Packkey
         
         --Debug insert traceinfo
         --IF ISNULL(@n_Pallet,0) = 0 OR ISNULL(@n_CaseCnt,0) = 0
         --BEGIN
            --INSERT INTO TRACEINFO (TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
            --SELECT 'isp_ReplenishmentRpt_PC31', GETDATE(), '@n_Pallet','@n_CaseCNT','@c_UOM','@c_Packkey','@c_ToLocationType',CAST(@n_Pallet AS NVARCHAR(10)),CAST(@n_CaseCnt AS NVARCHAR(10)),@c_UOM,@c_Packkey,@c_ToLocationType
            --SELECT CAST(@n_Pallet AS NVARCHAR(10)) AS Pallet,
            --       CAST(@n_CaseCnt AS NVARCHAR(10)) AS CaseCnt,
            --       @c_UOM AS UOM,
            --       @c_Packkey AS Packkey,
            --       @c_ToLocationType AS ToLocationType 
         --END

         IF @c_ToLocationType = 'PALLET' AND @n_Pallet = 0
         BEGIN
            GOTO NEXT_SKUxLOC
         END

         IF @c_ToLocationType = 'CASE' AND @n_CaseCnt = 0
         BEGIN
            GOTO NEXT_SKUxLOC
         END

         SET @c_NoMixLottable02  = '0'
         SELECT @c_NoMixLottable02 = ISNULL(RTRIM(NoMixLottable02),'0')
         FROM LOC WITH (NOLOCK)
         WHERE Loc = @c_CurrentLoc

         IF @c_NoMixLottable02 = ''
         BEGIN
            SET @c_NoMixLottable02 = '0'
         END

         SET @n_InvCnt = 0
         SET @c_Lottable02 = ''
         SELECT TOP 1 @n_InvCnt = 1
               , @c_Lottable02 = ISNULL(RTRIM(LA.lottable02),'')
         FROM LOTxLOCxID LLI  WITH (NOLOCK)
         JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
         WHERE LLI.Storerkey = @c_CurrentStorer
         AND LLI.Sku = @c_CurrentSku
         AND LLI.Loc = @c_CurrentLoc
         AND LLI.Qty - LLI.QtyPicked > 0

         IF @c_Storerkey_CL <> @c_Storerkey
         BEGIN
            SET @c_ReplFullPallet = 'N'
            SET @c_ReplFreshStock = 'N'
            SET @c_CaseToPick     = 'N'
            SELECT @c_ReplFullPallet = ISNULL(MAX(CASE WHEN CL.Code ='ReplFullPallet' THEN 'Y' ELSE 'N' END),'N')
                  ,@c_ReplFreshStock = ISNULL(MAX(CASE WHEN CL.Code ='ReplFreshStock' THEN 'Y' ELSE 'N' END),'N')
                  ,@c_CaseToPick     = ISNULL(MAX(CASE WHEN CL.Code ='REPLCASETOPICK' THEN 'Y' ELSE 'N' END),'N')
            FROM CODELKUP CL WITH (NOLOCK)
            WHERE CL.ListName = 'REPORTCFG' 
            AND CL.Long = 'r_replenishment_report_pc31'
            AND CL.Storerkey = @c_Storerkey
            AND CL.Short = 'Y'
                        
            SET @c_Storerkey_CL = @c_Storerkey
         END  

         SET @n_FilterQty = 1
         IF @c_ReplFullPallet = 'Y'
         BEGIN
            IF @n_Pallet = 0  
            BEGIN  
               GOTO NEXT_SKUxLOC    
            END  
            SET @n_FilterQty = @n_Pallet  
         END


         SET @n_ShelfLife = 0
         SET @d_today = CONVERT(DATETIME,'1900-01-01')
         IF @c_ReplFreshStock = 'Y'
         BEGIN
            IF ISNUMERIC(@c_SUSR2) = 1
            BEGIN
               SET @n_ShelfLife = CONVERT(INT, @c_SUSR2)  
            END
            SET @d_today = CONVERT(NVARCHAR(10), GETDATE(),120) 
         END

         IF EXISTS(SELECT 1
                   FROM CODELKUP CL (NOLOCK)
                   WHERE CL.Listname = 'REPORTCFG'
                   AND CL.Code = 'UNISORT'
                   AND CL.Long = 'r_replenishment_report_pc31'
                   AND CL.Storerkey = @c_Storerkey
                   AND ISNULL(CL.Short,'') <> 'N') --NJOW01
         BEGIN                   	    
            SET @CUR_REPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOTxLOCxID.LOT
                  ,LOTxLOCxID.Loc
                  ,LOTxLOCxID.ID
                  ,LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen  
                  ,LOTxLOCxID.QtyAllocated
                  ,LOTxLOCxID.QtyPicked
                  ,LOTATTRIBUTE.Lottable02
            FROM LOT          WITH (NOLOCK)
            JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot        = LOTATTRIBUTE.LOT)
            JOIN LOTxLOCxID   WITH (NOLOCK) ON (LOT.Lot        = LOTxLOCxID.Lot)
            JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
            WHERE LOTxLOCxID.LOC <> @c_CurrentLoc
            AND LOTxLOCxID.StorerKey = @c_CurrentStorer
            AND LOTxLOCxID.SKU = @c_CurrentSku
            AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen >= @n_FilterQty    
            AND LOTxLOCxID.QtyExpected = 0 
            AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
            AND LOC.LocationType NOT IN (CASE WHEN @c_ReplGrp = 'CASE' THEN '' ELSE 'PALLET' END   
                                       , CASE WHEN @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y' THEN '' ELSE 'CASE' END  
                                       ,'PICK')
            AND LOC.LocationType = CASE WHEN @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y' THEN 'CASE' ELSE LOC.LocationType END 
            AND LOC.LocationType NOT IN ('PND','OTHER') 
            AND LOC.Status     <> 'HOLD'
            AND LOC.Facility   = @c_Zone01
            AND(LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11)
            OR  @c_zone02 = 'ALL')
            AND LOT.Status= 'OK'
            AND (@c_NoMixLottable02= '0' OR 
                (@c_NoMixLottable02= '1' AND @n_InvCnt > 0 AND LOTATTRIBUTE.Lottable02= @c_Lottable02))
            AND (@c_ReplFreshStock = 'N' OR                                                                 
                (@c_ReplFreshStock = 'Y' AND LOTATTRIBUTE.Lottable04 > DATEADD(d, @n_ShelfLife, @d_today))) 
            ORDER BY ISNULL(LOTATTRIBUTE.LOTTABLE04, '1900-01-01')   
                  ,  LOTATTRIBUTE.LOTTABLE02
                  ,  CASE WHEN ISNULL(LOTATTRIBUTE.LOTTABLE04, '1900-01-01') = '1900-01-01' THEN LOTATTRIBUTE.LOTTABLE05 ELSE NULL END
                  ,  CASE WHEN (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) < @n_Pallet 
                          THEN 1 
                          ELSE 2
                          END
                  ,  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked)
                  ,  LOC.LogicalLocation
                  ,  LOC.Loc
                  ,  LOTxLOCxID.LOT
                  ,  LOTxLOCxID.ID
         END
         ELSE
         BEGIN
           SET @CUR_REPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LOTxLOCxID.LOT
                  ,LOTxLOCxID.Loc
                  ,LOTxLOCxID.ID
                  ,LOTxLOCxID.Qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen  
                  ,LOTxLOCxID.QtyAllocated
                  ,LOTxLOCxID.QtyPicked
                  ,LOTATTRIBUTE.Lottable02
            FROM LOT          WITH (NOLOCK)
            JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.Lot        = LOTATTRIBUTE.LOT)
            JOIN LOTxLOCxID   WITH (NOLOCK) ON (LOT.Lot        = LOTxLOCxID.Lot)
            JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
            WHERE LOTxLOCxID.LOC <> @c_CurrentLoc
            AND LOTxLOCxID.StorerKey = @c_CurrentStorer
            AND LOTxLOCxID.SKU = @c_CurrentSku
            AND LOTxLOCxID.qty - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyReplen >= @n_FilterQty    
            AND LOTxLOCxID.QtyExpected = 0 
            AND LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')
            AND LOC.LocationType NOT IN (CASE WHEN @c_ReplGrp = 'CASE' THEN '' ELSE 'PALLET' END   
                                       , CASE WHEN @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y' THEN '' ELSE 'CASE' END  
                                       ,'PICK')
            AND LOC.LocationType = CASE WHEN @c_ToLocationType = 'PICK' AND @c_CaseToPick = 'Y' THEN 'CASE' ELSE LOC.LocationType END  
            AND LOC.LocationType NOT IN ('PND','OTHER') 
            AND LOC.Status     <> 'HOLD'
            AND LOC.Facility   = @c_Zone01
            AND(LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11)
            OR  @c_zone02 = 'ALL')
            AND LOT.Status= 'OK'
            AND (@c_NoMixLottable02= '0' OR 
                (@c_NoMixLottable02= '1' AND @n_InvCnt > 0 AND LOTATTRIBUTE.Lottable02= @c_Lottable02))
            AND (@c_ReplFreshStock = 'N' OR                                                                 
                (@c_ReplFreshStock = 'Y' AND LOTATTRIBUTE.Lottable04 > DATEADD(d, @n_ShelfLife, @d_today))) 
            ORDER BY ISNULL(LOTATTRIBUTE.LOTTABLE04, '1900-01-01')   
                  ,  ISNULL(LOTATTRIBUTE.LOTTABLE05, '1900-01-01')
                  ,  CASE WHEN (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked - LOTxLOCxID.QtyReplen) < @n_Pallet 
                          THEN 1 
                          ELSE 2
                          END
                  ,  (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked)
                  ,  LOTxLOCxID.LOT
                  ,  LOTxLOCxID.ID
         END
               
         OPEN @CUR_REPL

         FETCH NEXT FROM @CUR_REPL INTO   @c_FromLot
                                       ,  @c_FromLoc
                                       ,  @c_FromID
                                       ,  @n_FromQty
                                       ,  @n_QtyAllocated
                                       ,  @n_QtyPicked
                                       ,  @c_ReplLottable02

         WHILE @@Fetch_Status <> -1 AND @n_RemainingQty > 0
         BEGIN
            IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                        WHERE LOT = @c_fromlot 
                        AND FromLOC = @c_FromLOC 
                        AND ID = @c_fromid
                        GROUP BY LOT, FromLOC, ID
                        HAVING @n_FromQty - SUM(Qty) < @n_FilterQty
                      )
            BEGIN
               GOTO NEXT_CANDIDATE
            END

            IF @c_NoMixLottable02 = '1' AND @n_InvCnt = 0
            BEGIN
               IF EXISTS ( SELECT 1 FROM #REPLENISHMENT
                           WHERE Storerkey = @c_CurrentStorer AND Sku = @c_CurrentSku AND ToLOC = @c_CurrentLoc
                           AND ReplLottable02 <> @c_ReplLottable02
                           GROUP BY Storerkey, Sku, ToLoc
                           HAVING COUNT(1) > 0)
               BEGIN
                  GOTO NEXT_CANDIDATE
               END
            END

            IF EXISTS(SELECT 1 FROM ID (NOLOCK) WHERE ID = @c_FromID AND STATUS = 'HOLD')
            BEGIN
               GOTO NEXT_CANDIDATE
            END

            IF EXISTS(SELECT 1 FROM #REPLENISHMENT
                      WHERE LOT =  @c_fromlot AND FromLOC = @c_FromLOC AND ID = @c_fromid)
            BEGIN
               GOTO NEXT_CANDIDATE
            END

            SELECT @c_ReplValidationRules = SC.sValue
            FROM STORERCONFIG SC (NOLOCK)
            JOIN CODELKUP CL (NOLOCK) ON SC.sValue = CL.Listname
            WHERE SC.StorerKey = @c_StorerKey
            AND SC.Configkey = 'ReplenValidation'

            IF ISNULL(@c_ReplValidationRules,'') <> ''
            BEGIN
               EXEC isp_REPL_ExtendedValidation @c_fromlot = @c_fromlot
                                             ,  @c_FromLOC = @c_FromLOC
                                             ,  @c_fromid  = @c_fromid
                                             ,  @c_ReplValidationRules=@c_ReplValidationRules
                                             ,  @b_Success = @b_Success OUTPUT
                                             ,  @c_ErrMsg  = @c_ErrMsg OUTPUT
               IF @b_Success = 0
               BEGIN
                  GOTO NEXT_CANDIDATE
               END
            END

            IF @c_ToLocationType = 'PALLET'
            BEGIN
               IF @n_FromQty < @n_Pallet
               BEGIN
                  GOTO NEXT_CANDIDATE
               END

               IF @n_FromQty > @n_RemainingQty
               BEGIN
                  SET @n_FromQty = FLOOR(@n_RemainingQty/@n_Pallet) * @n_Pallet
               END
               ELSE
               BEGIN
                  SET @n_FromQty = FLOOR(@n_FromQty/@n_Pallet) * @n_Pallet
               END
            END
            ELSE IF @c_ToLocationType = 'CASE'
            BEGIN

               IF @b_debug = 1 AND @c_CurrentSku = '67819998'
               BEGIN
                  print    ' @n_FromQty: ' + cast(@n_FromQty as nvarchar)
                        +  ',@n_Pallet: ' + cast(@n_Pallet as nvarchar)
                        +  ',@n_CaseCnt: ' + cast(@n_CaseCnt as nvarchar)
                        +  ',@n_RemainingQty: ' + cast(@n_RemainingQty as nvarchar)
                        +  ',@c_CurrentSku: ' + @c_CurrentSku
                        + ', @c_FromLot: ' + @c_FromLot
                        + ', @c_FromLoc: ' + @c_FromLoc
                        + ', @c_Fromid: ' + @c_Fromid
               END

               IF @n_FromQty < @n_CaseCnt
               BEGIN
                  GOTO NEXT_CANDIDATE
               END


               SELECT @c_LottableName = ''
               SELECT TOP 1 @c_LottableName = Code
               FROM CODELKUP (NOLOCK)  
               WHERE Listname = 'REPLENLOT'  
               AND Storerkey = @c_StorerKey  
               --AND Short = 'Y'  
               ORDER BY Code  

               SET @c_LottableValue = ''
               IF ISNULL(@c_LottableName,'') <> ''
               BEGIN

     
               SET @c_SQL = N'SELECT TOP 1 @c_LottableValue = LA.' + RTRIM(LTRIM(@c_LottableName))  +  
                             ' FROM LOTATTRIBUTE LA (NOLOCK)      
                             WHERE LA.StorerKey = @c_Storerkey     
                             AND LA.lot = @c_FromLot  '   
                             -- AND LLI.Loc = @c_CurrentLoc''    
           
               EXEC sp_executesql @c_SQL,  
               N'@c_LottableValue NVARCHAR(30) OUTPUT, @c_Storerkey NVARCHAR(15), @c_FromLot NVARCHAR(20)',   
               @c_LottableValue OUTPUT,  
               @c_Storerkey,  
               @c_FromLot
            END
            --    print @c_SQL
            --select @c_SQL
            --select @c_Storerkey'@c_Storerkey', @c_FromLot '@c_FromLot',@c_LottableName '@c_LottableName',@c_LottableValue 'c_LottableValue'

   
               IF ISNULL(@c_LottableValue,'') <> ''    --CS02
               BEGIN  
                  GOTO NEXT_CANDIDATE    
               END  

               IF @n_FromQty > @n_RemainingQty
               BEGIN
                  IF @c_CaseToPick = 'Y' 
                  BEGIN
                     IF CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt > @n_FromQty     
                        SET @n_FromQty = FLOOR(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt                      
                     ELSE              
                        SET @n_FromQty = CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt                    
                  END
                  ELSE
                  BEGIN 
                     IF @c_ReplFullPallet = 'Y'
                     BEGIN
                        IF @n_RemainingQty >= @n_Pallet
                        BEGIN
                           SET @n_FromQty = FLOOR(@n_RemainingQty/@n_Pallet) * @n_Pallet  
                        END
                        ELSE 
                        BEGIN
                           SET @n_FromQty = 0 
                        END
                     END
                     ELSE
                     BEGIN
                        SET @n_FromQty = 0 
                     END
                  END
               END
               ELSE
               BEGIN
                  IF @n_FromQty < @n_Pallet
                  BEGIN
                  	--SET @n_FromQty = FLOOR(@n_FromQty/@n_CaseCnt) * @n_CaseCnt
                     SET @n_FromQty = CASE WHEN @n_CaseCnt = 0 THEN 0 ELSE FLOOR(@n_FromQty/@n_CaseCnt) * @n_CaseCnt END
                  END
                  ELSE
                  BEGIN
                     --SET @n_FromQty = FLOOR(@n_FromQty/@n_Pallet) * @n_Pallet
                     SET @n_FromQty = CASE WHEN @n_Pallet = 0 THEN 0 ELSE FLOOR(@n_FromQty/@n_Pallet) * @n_Pallet END
                  END
               END
            END
            ELSE IF @c_ToLocationType = 'PICK' AND  @c_CaseToPick = 'Y' 
            BEGIN
               IF @n_FromQty > @n_RemainingQty
                  IF CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt > @n_FromQty
                     SET @n_FromQty = FLOOR(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt                                                       
                  ELSE
                     SET @n_FromQty = CEILING(@n_RemainingQty/@n_CaseCnt) * @n_CaseCnt                                                        
               ELSE
                  SET @n_FromQty = FLOOR(@n_FromQty/@n_CaseCnt) * @n_CaseCnt
            END

            SET @n_RemainingQty = @n_RemainingQty - @n_FromQty

            IF @n_FromQty > 0
            BEGIN

               IF @b_debug = 1  
               BEGIN
                  print    ' @n_FromQty: ' + cast(@n_FromQty as nvarchar)
                        + ', @c_FromLot: ' + @c_FromLot
                        + ', @c_FromLoc: ' + @c_FromLoc
                        + ', @c_Fromid: ' + @c_Fromid
               END
               INSERT #REPLENISHMENT
                     (
                        StorerKey
                     ,  SKU
                     ,  FromLOC
                     ,  ToLOC
                     ,  Lot
                     ,  Id
                     ,  Qty
                     ,  UOM
                     ,  PackKey
                     ,  Priority
                     ,  QtyMoved
                     ,  QtyInPickLOC
                     ,  ReplLottable02
                     )
                        VALUES
                     (
                        @c_CurrentStorer
                     ,  @c_CurrentSKU
                     ,  @c_FromLOC
                     ,  @c_CurrentLoc
                     ,  @c_FromLot
                     ,  @c_Fromid
                     ,  @n_FromQty
                     ,  @c_UOM
                     ,  @c_Packkey
                     ,  @c_CurrentPriority
                     ,  @n_QtyAllocated
                     ,  @n_QtyPicked
                     ,  @c_ReplLottable02
                     )

               SET @n_numberofrecs = @n_numberofrecs + 1

               IF @b_debug = 1
               BEGIN
                  SELECT 'INSERTED : ' as Title, @c_CurrentSKU ' SKU', @c_fromlot 'LOT',  @c_CurrentLoc 'LOC', @c_fromid 'ID',
                         @n_FromQty 'Qty'
               END
            END

            IF @b_debug = 1
            BEGIN
               select @c_CurrentSKU ' SKU', @c_CurrentLoc 'LOC', @c_CurrentPriority 'priority', @n_currentfullcase 'full case', @n_CurrentSeverity 'severity'
               select @n_RemainingQty '@n_RemainingQty', @c_CurrentLoc + ' SKU = ' + @c_CurrentSKU, @c_fromlot 'from lot', @c_fromid
            END

            NEXT_CANDIDATE:
            FETCH NEXT FROM @CUR_REPL INTO   @c_FromLot
                                          ,  @c_FromLoc
                                          ,  @c_FromID
                                          ,  @n_FromQty
                                          ,  @n_QtyAllocated
                                          ,  @n_QtyPicked
                                          ,  @c_ReplLottable02
         END -- LOT
         CLOSE @CUR_REPL
         DEALLOCATE @CUR_REPL

         NEXT_SKUxLOC:
         FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentStorer
                                       ,  @c_CurrentSKU
                                       ,  @c_CurrentLoc
                                       ,  @n_CurrentSeverity
                                       ,  @c_CurrentPriority
                                       ,  @c_ToLocationtype
                                       ,  @c_Packkey
                                       ,  @c_SUSR2  
      END -- -- FOR SKUxLOC
      CLOSE CUR_SKUxLOC
      DEALLOCATE CUR_SKUxLOC
   END

   /* Insert Into Replenishment Table Now */
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT R.FromLoc
         ,R.Id
         ,R.ToLoc
         ,R.Sku
         ,R.Qty
         ,R.StorerKey
         ,R.Lot
         ,R.PackKey
         ,R.Priority
         ,R.UOM
   FROM #REPLENISHMENT R

   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_FromLOC
                           , @c_FromID
                           , @c_CurrentLoc
                           , @c_CurrentSKU
                           , @n_FromQty
                           , @c_CurrentStorer
                           , @c_FromLot
                           , @c_PackKey
                           , @c_Priority
                           , @c_UOM
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE SKUxLoc WITH (ROWLOCK)
      SET ReplenishmentPriority = @c_Priority, TrafficCop = NULL, EditWho = SUSER_SNAME(), EditDate = GETDATE()
      WHERE Storerkey = @c_CurrentStorer
      AND SKU = @c_CurrentSKU
      AND LOC = @c_CurrentLoc

      --IF @@ERROR <> 0  
      --BEGIN  
      --   GOTO NEXT_REC  
      --END  

      EXECUTE nspg_GetKey
            'REPLENISHKEY'
         ,  10
         ,  @c_ReplenishmentKey  OUTPUT
         ,   @b_success          OUTPUT
         ,   @n_err              OUTPUT
         ,   @c_errmsg           OUTPUT

      IF NOT @b_success = 1
      BEGIN
         BREAK
      END

      IF @b_success = 1
      BEGIN
         INSERT REPLENISHMENT
            (
               replenishmentgroup
            ,  ReplenishmentKey
            ,  StorerKey
            ,  Sku
            ,  FromLoc
            ,  ToLoc
            ,  Lot
            ,  Id
            ,  Qty
            ,  UOM
            ,  PackKey
            ,  Confirmed
            ,  RefNo 
            --,  QtyReplen
            --,  PendingMoveIn
            ,  Priority
            --,  Loadkey
            --,  Wavekey 
            )
               VALUES (
               @c_ReplenishmentGroup           
            ,  @c_ReplenishmentKey
            ,  @c_CurrentStorer
            ,  @c_CurrentSKU
            ,  @c_FromLOC
            ,  @c_CurrentLoc
            ,  @c_FromLot
            ,  @c_FromId
            ,  @n_FromQty
            ,  @c_UOM
            ,  @c_PackKey
            ,  'N'
            ,  'PC29' 
            --,  @n_FromQty
            --,  @n_FromQty
            ,  @c_Priority
            --,  ''    -- Loadkey
            --,  ''    -- Wavekey
            )
         SET @n_err = @@ERROR

      END -- IF @b_success = 1
NEXT_REC:
      FETCH NEXT FROM CUR1 INTO @c_FromLOC
                              , @c_FromID
                              , @c_CurrentLoc
                              , @c_CurrentSKU
                              , @n_FromQty
                              , @c_CurrentStorer
                              , @c_FromLot
                              , @c_PackKey
                              , @c_Priority
                              , @c_UOM
   END -- While
   CLOSE CUR1
   DEALLOCATE CUR1
   -- End Insert Replenishment

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'Cur_Taskdetail') IN (0 , 1)
   BEGIN
      CLOSE Cur_Taskdetail
      DEALLOCATE Cur_Taskdetail   
   END

   IF @c_backendjob <> 'Y' 
   BEGIN
      IF @c_FuncType IN ( 'G' )                                     
      BEGIN
         RETURN
      END

      SELECT R.FromLoc
            ,R.Id
            ,R.ToLoc
            ,R.Sku
            ,R.Qty
            ,R.StorerKey
            ,R.Lot
            ,R.PackKey
            ,SKU.Descr
            ,R.Priority
            ,CASE WHEN ISNULL(CLR.Code,'') = ''    
                  THEN LOC.PutawayZone ELSE '' END AS Putawayzone 
            ,PACK.CaseCnt
            ,PACK.Pallet
            ,NoOfCSInPL = CASE WHEN PACK.CaseCnt > 0 THEN PACK.Pallet / PACK.CaseCnt ELSE 0 END
            ,SuggestPL  = CASE WHEN PACK.Pallet  > 0 THEN FLOOR(R.Qty / PACK.Pallet) ELSE 0 END
            ,SuggestCS  = CASE WHEN PACK.CaseCnt > 0 THEN FLOOR((R.Qty % CONVERT(INT, PACK.Pallet)) / PACK.CaseCnt) ELSE 0 END
            ,TotalCS    = CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(R.Qty / PACK.CaseCnt) ELSE 0 END
            ,PACK.PackUOM1
            ,PACK.PackUOM3
            ,R.ReplenishmentKey
            ,LA.Lottable02
            ,CASE WHEN ISNULL(CLR.Code,'') <> ''    
                  THEN FRLOC.LocationGroup ELSE '' END AS LocationGroup 
            ,CASE WHEN ISNULL(CLR.Code,'') <> ''    
                  THEN CASE WHEN LOC.LocationType = 'CASE' THEN 'Pick-Case'
                            WHEN LOC.LocationType = 'PICK' THEN 'Pick-Piece'
                            ELSE LOC.LocationType END
                  ELSE '' END AS LocationType 
      FROM  REPLENISHMENT R WITH (NOLOCK)
      JOIN  SKU             WITH (NOLOCK) ON (SKU.Sku = R.Sku AND  SKU.StorerKey = R.StorerKey)
      JOIN  LOC             WITH (NOLOCK) ON (LOC.Loc = R.ToLoc)
      JOIN  LOC FRLOC       WITH (NOLOCK) ON (R.FromLoc = FRLOC.Loc) 
      JOIN  PACK            WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      JOIN  LOTATTRIBUTE LA WITH (NOLOCK) ON (R.Lot = LA.Lot)
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (R.Storerkey = CLR.Storerkey AND CLR.Code = 'REPLCASETOPICK' 
                                            AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_replenishment_report_pc31' AND ISNULL(CLR.Short,'') <> 'N')   --NJOW02      
      WHERE(LOC.PickZone = @c_ReplGrp OR @c_ReplGrp = 'ALL')
      AND   LOC.facility = @c_zone01
      AND  (R.Storerkey  = @c_Storerkey OR @c_Storerkey = 'ALL')
      AND  (LOC.PutawayZone IN (@c_zone02, @c_zone03, @c_zone04, @c_zone05, @c_zone06, @c_zone07, @c_zone08, @c_zone09, @c_zone10, @c_zone11)
      OR  @c_zone02 = 'ALL')
      AND R.Confirmed = 'N'
      AND (SKU.ABC = @c_zone12 OR @c_zone12 IN ('ALL', ''))
      AND (R.Wavekey = '' OR R.Wavekey IS NULL)
      AND (R.Loadkey = '' OR R.Loadkey IS NULL)
      ORDER BY CASE WHEN ISNULL(CLR.Code,'') <> '' THEN   
               FRLOC.LocationGroup ELSE LOC.PutawayZone END 
            ,  CASE WHEN ISNULL(CLR.Code,'') <> '' THEN   
                    LOC.LocationType ELSE '' END  
            ,  FRLOC.LogicalLocation 
            ,  R.FromLoc
            ,  R.Id
            ,  LA.Lottable02
            ,  R.Sku
   END

END

GO