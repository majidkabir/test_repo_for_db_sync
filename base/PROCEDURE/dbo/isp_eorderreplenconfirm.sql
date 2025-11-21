SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* SP: isp_EOrderReplenConfirm                                          */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Update Pickdetail UOM from 7 to 6                           */
/*          7: Required Replenishment 6=No replenishment needed         */
/* Usage:                                                               */
/*                                                                      */
/* Called By: nsp_ConfirmReplenishment                                  */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 12-Nov-2020  Shong   1.1   Offset the Pickdetail if Lot replen is not*/
/*                            same as expected LOT                      */
/* 25-Nov-2020  Shong   1.2   Cater ForceAllocLottable Setting          */
/* 21-Jan-2020  WWANG01 1.3   Cater Replenish include Allocation qty    */
/* 25-Oct-2022  SYCHUA  1.4   JSM-104400 Bug Fix to include Channel_ID  */
/*                            when INSERT INTO PICKDETAIL (SY01)        */
/************************************************************************/
CREATE   PROC [dbo].[isp_EOrderReplenConfirm] (
   @c_ReplenishmentGroup   NVARCHAR(10)
  ,@c_ReplenishmentKey     NVARCHAR(10)
  ,@b_Success              INT = 1 OUTPUT
  ,@n_Err                  INT = 0 OUTPUT
  ,@c_Errmsg               NVARCHAR(255) = '' OUTPUT
  ,@b_Debug                INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_SKU                NVARCHAR(20),
           @n_QtyOrdered         INT,
           @c_Facility           NVARCHAR(5),
           @c_LOC                NVARCHAR(10),
           @c_ToLOC              NVARCHAR(10),
           @c_LOT                NVARCHAR(10),
           @c_ID                 NVARCHAR(20),
           @n_CaseCnt            INT,
           @n_RemainReplenQty    INT,
           @n_ReplenQty          INT,
           @n_SwapLotQty         INT,
           @c_StorerKey          NVARCHAR(15),
           @n_StartTCnt          INT,
           @n_Continue           INT,
           @c_SQL                  NVARCHAR(2000),
           @c_LoadKey              NVARCHAR(10),
           @c_PickDetailKey        NVARCHAR(18) ='',
           @c_NewPickDetailKey     NVARCHAR(18) = '',
           @c_SwapPickDetailKey    NVARCHAR(18) = '',
           @c_NewSwapPickDetailKey NVARCHAR(18) = '',
           @n_QtyAvaliable        INT = 0 ,
           @n_QtyAvaliableLOT     INT = 0 ,
           @b_ExistsFlag          BIT,
           @n_QtyAlloc            INT,
           @n_NewQtyAlloc         INT,
           @n_QtyTakeFromPickLoc  INT,
           @n_LooseQtyFromBulk    INT,
           @n_FullCasePickQty     INT,
           @c_MoveRefKey          NVARCHAR(10),
           @c_ToID                NVARCHAR(20),
           @n_QtyToTake           INT,
           @n_QtyReplan           INT = 0,
           @n_QtyInPickLoc        INT = 0, --WWANG02
           @n_PT_RowRef           BIGINT = 0,
           @c_FastPickLoc         CHAR(1) = 'N',
           @c_PickLOT             NVARCHAR(10),
           @c_PickID              NVARCHAR(10)

   DECLARE @c_Lottable01          NVARCHAR(18)  = '',
           @c_Lottable02          NVARCHAR(18)  = '',
           @c_Lottable03          NVARCHAR(18)  = '',
           @d_Lottable04          DATETIME,
           @c_SQLSelect           NVARCHAR(4000),
           @c_Lottable06          NVARCHAR(30) = '',
           @c_Lottable07          NVARCHAR(30) = '',
           @c_Lottable08          NVARCHAR(30) = '',
           @c_Lottable09          NVARCHAR(30) = '',
           @c_Lottable10          NVARCHAR(30) = '',
           @c_Lottable11          NVARCHAR(30) = '',
           @c_Lottable12          NVARCHAR(30) = '',
           @c_ForceAllocLottable  NVARCHAR(1) = '0',
           @c_ForceLottableList   NVARCHAR(500) = ''


    SET @n_RemainReplenQty = 0
    SET @n_ReplenQty = 0

    SELECT @c_LOT = r.LOT,
           @c_LOC = r.ToLoc,
           @c_ToID  = ISNULL(r.ToID,''),
           @c_Facility = L.Facility,
           @c_StorerKey = r.Storerkey,
           @c_SKU = r.Sku,
           @n_RemainReplenQty =  r.Qty -  r.QtyInPickLoc,
           @n_ReplenQty = CASE WHEN r.QtyInPickLoc > r.Qty THEN r.Qty ELSE r.QtyInPickLoc END,
           @c_MoveRefKey = MoveRefKey   --WWANG01
    FROM REPLENISHMENT AS r WITH(NOLOCK)
    JOIN LOC AS l WITH(NOLOCK) ON r.ToLoc = L.Loc
    WHERE r.ReplenishmentKey = @c_ReplenishmentKey

   --WWANG01 BEGIN  QtyAllocate in current Batch
    IF @c_MoveRefKey Like 'E%'
    BEGIN
      SELECT @n_QtyInPickLoc = SUM(Qty)
      FROM PICKDETAIL AS PD WITH (NOLOCK)
      JOIN PackTask PT WITH (NOLOCK) ON PD.OrderKey = PT.OrderKey
      WHERE PT.ReplenishmentGroup = @c_ReplenishmentGroup
      AND   PD.MoveRefKey = @c_MoveRefKey

      IF @n_QtyInPickLoc > 0
      BEGIN

        SET @n_RemainReplenQty = @n_RemainReplenQty - @n_QtyInPickLoc
            SET @n_ReplenQty = @n_ReplenQty + @n_QtyInPickLoc

      END --@n_QtyInPickLoc > 0

    END --c_MoveRefKey like '%E'

   --WWANG01 END

   SET @c_ForceAllocLottable = '0'

   SELECT @b_success = 0
   EXECUTE nspGetRight
            @c_facility,    -- facility
            @c_Storerkey,   -- Storerkey
            '',             -- Sku
            'ForceAllocLottable', -- Configkey
            @b_success              OUTPUT,
            @c_ForceAllocLottable   OUTPUT,
            @n_err                  OUTPUT,
            @c_errmsg               OUTPUT

   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 78308
      SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': nspGetRight ForceAllocLottable Failed! (isp_GenEOrder_Replenishment)'
      GOTO EXIT_SP
   END

   IF @c_ForceAllocLottable = '1'
   BEGIN
      SELECT TOP 1 @c_ForceLottableList = NOTES
      FROM CODELKUP (NOLOCK)
      WHERE Storerkey = @c_StorerKey
      AND Listname = 'FORCEALLOT'

      IF ISNULL(@c_ForceLottableList,'') = ''
         SET @c_ForceLottableList = 'LOTTABLE01,LOTTABLE02,LOTTABLE03'
   END
   ELSE
      SET @c_ForceLottableList = ''


-- Swap LOT When Replenishment Lot not similar to the LOT in Pickdetail.
   IF @c_ForceAllocLottable = '1'
   BEGIN
      SELECT
         @c_Lottable01 = Lottable01,
         @c_Lottable02 = Lottable02,
         @c_Lottable03 = Lottable03,
         @c_Lottable06 = Lottable06,
         @c_Lottable07 = Lottable07,
         @c_Lottable08 = Lottable08,
         @c_Lottable09 = Lottable09,
         @c_Lottable10 = Lottable10,
         @c_Lottable11 = Lottable11,
         @c_Lottable12 = Lottable12
      FROM LOTATTRIBUTE LA WITH (NOLOCK)
      WHERE LOT = @c_LOT

      SELECT @c_SQLSelect =
    N'DECLARE CUR_OFFSET_PICKDETAIL CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, PD.LOT, PD.ID, PD.Qty
      FROM PICKDETAIL AS PD WITH (NOLOCK)
      JOIN LOTATTRIBUTE AS LA WITH (NOLOCK) ON LA.LOT = PD.LOT
      JOIN PackTask PT WITH (NOLOCK) ON PD.OrderKey = PT.OrderKey
      JOIN (SELECT StorerKey, SKU, LOT, ID, SUM(Qty - QtyAllocated - QtyPicked) AS AvaQty
            FROM LOTxLOCxID WITH (NOLOCK)
            WHERE StorerKey = @c_StorerKey
            AND   SKU = @c_SKU
            GROUP BY StorerKey, SKU, LOT, ID ) AS LLI ON PD.StorerKey = LLI.StorerKey AND PD.SKU = LLI.SKU AND PD.LOT = LLI.LOT AND PD.ID = LLI.ID
      WHERE PT.ReplenishmentGroup = @c_ReplenishmentGroup
      AND   PD.LOC = @c_LOC
      AND   PD.StorerKey = @c_StorerKey
      AND   PD.SKU = @c_SKU
      AND   PD.UOM = ''7''
      AND   PD.Qty > 0
      AND   PD.STATUS < ''4''
      AND   PD.ShipFlag NOT IN (''P'',''Y'')
      AND   ISNULL(PD.CartonGroup,'''') <> ''ReplenSwap'' '+
      CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') <> '' AND CHARINDEX('LOTTABLE01', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable01 = @c_Lottable01 ' ELSE '' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') <> '' AND CHARINDEX('LOTTABLE02', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable02 = @c_Lottable02 ' ELSE '' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') <> '' AND CHARINDEX('LOTTABLE03', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable03 = @c_Lottable03 ' ELSE '' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') <> '' AND CHARINDEX('LOTTABLE06', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable06 = @c_Lottable06 ' ELSE '' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') <> '' AND CHARINDEX('LOTTABLE07', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable07 = @c_Lottable07 ' ELSE '' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') <> '' AND CHARINDEX('LOTTABLE08', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable08 = @c_Lottable08 ' ELSE '' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') <> '' AND CHARINDEX('LOTTABLE09', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable09 = @c_Lottable09 ' ELSE '' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') <> '' AND CHARINDEX('LOTTABLE10', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable10 = @c_Lottable10 ' ELSE '' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') <> '' AND CHARINDEX('LOTTABLE11', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable11 = @c_Lottable11 ' ELSE '' END +
      CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') <> '' AND CHARINDEX('LOTTABLE12', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable12 = @c_Lottable12 ' ELSE '' END +
      N'  ORDER BY CASE WHEN PD.LOT = @c_LOT AND PD.ID = @c_ToID THEN 1
                         WHEN PD.LOT = @c_LOT AND PD.ID <> @c_ToID THEN 2
                         ELSE 2
                    END , LLI.AvaQty DESC, PickDetailKey    '


      IF @b_Debug=1
      BEGIN
         PRINT @c_SQLSelect
      END

      EXEC sp_executesql @c_SQLSelect,
         N'@c_ReplenishmentGroup NVARCHAR(10)
         , @c_StorerKey  NVARCHAR(15)
         , @c_LOC        NVARCHAR(10)
         , @c_SKU        NVARCHAR(20)
         , @c_LOT        NVARCHAR(10)
         , @c_ToID       NVARCHAR(18)
         , @c_Lottable01 NVARCHAR(18)
         , @c_Lottable02 NVARCHAR(18)
         , @c_Lottable03 NVARCHAR(18)
         , @d_Lottable04 DATETIME
         , @c_Lottable06 NVARCHAR(30)
         , @c_Lottable07 NVARCHAR(30)
         , @c_Lottable08 NVARCHAR(30)
         , @c_Lottable09 NVARCHAR(30)
         , @c_Lottable10 NVARCHAR(30)
         , @c_Lottable11 NVARCHAR(30)
         , @c_Lottable12 NVARCHAR(30)'
         , @c_ReplenishmentGroup
         , @c_StorerKey
         , @c_LOC
         , @c_SKU
         , @c_LOT
         , @c_ToID
         , @c_Lottable01
         , @c_Lottable02
         , @c_Lottable03
         , @d_Lottable04
         , @c_Lottable06
         , @c_Lottable07
         , @c_Lottable08
         , @c_Lottable09
         , @c_Lottable10
         , @c_Lottable11
         , @c_Lottable12

   END -- @c_ForceAllocLottable = '1'
   ELSE
   BEGIN
      DECLARE CUR_OFFSET_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, PD.LOT, PD.ID, PD.Qty
      FROM PICKDETAIL AS PD WITH (NOLOCK)
      JOIN PackTask PT WITH (NOLOCK) ON PD.OrderKey = PT.OrderKey
      JOIN (SELECT StorerKey, SKU, LOT, ID, SUM(Qty - QtyAllocated - QtyPicked) AS AvaQty
            FROM LOTxLOCxID WITH (NOLOCK)
            WHERE StorerKey = @c_StorerKey
            AND   SKU = @c_SKU
            GROUP BY StorerKey, SKU, LOT, ID ) AS LLI ON PD.StorerKey = LLI.StorerKey AND PD.SKU = LLI.SKU AND PD.LOT = LLI.LOT AND PD.ID = LLI.ID
      WHERE PT.ReplenishmentGroup = @c_ReplenishmentGroup
      AND   PD.LOC = @c_LOC
      AND   PD.StorerKey = @c_StorerKey
      AND   PD.SKU = @c_SKU
      AND   PD.UOM = '7'
      AND   PD.Qty > 0
      AND   PD.STATUS < '4'
      AND   PD.ShipFlag NOT IN ('P','Y')
      AND   ISNULL(PD.CartonGroup,'') <> 'ReplenSwap'
      ORDER BY CASE WHEN PD.LOT = @c_LOT AND PD.ID = @c_ToID THEN 1
                         WHEN PD.LOT = @c_LOT AND PD.ID <> @c_ToID THEN 2
                         ELSE 3
                    END, LLI.AvaQty DESC, PickDetailKey
   END


   OPEN CUR_OFFSET_PICKDETAIL

   FETCH NEXT FROM CUR_OFFSET_PICKDETAIL INTO @c_PickDetailKey, @c_PickLOT, @c_PickID, @n_QtyAlloc
   WHILE @@FETCH_STATUS = 0
   BEGIN

      IF @n_ReplenQty < @n_QtyAlloc
      BEGIN
         SET @c_NewPickDetailKey = ''

         EXECUTE dbo.nspg_GetKey
            'PICKDETAILKEY',
            10 ,
            @c_NewPickDetailKey  OUTPUT,
            @b_success        OUTPUT,
            @n_err            OUTPUT,
            @c_errmsg         OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @n_Err = 63885
            SET @c_ErrMsg = 'Get Pickdetail Key'
            SEt @n_Continue = 3
            GOTO EXIT_SP
         END

         IF @b_Debug = 1
         BEGIN
            PRINT '  *** Split PickDetail ***'
           PRINT '      New PickDetailKey: ' + @c_NewPickDetailKey + ', Qty: '
                 + CAST((@n_QtyAlloc -  @n_ReplenQty) AS VARCHAR(10))
         END

         INSERT INTO dbo.PICKDETAIL
            (
             PickDetailKey    ,CaseID           ,PickHeaderKey
            ,OrderKey         ,OrderLineNumber  ,Lot
            ,Storerkey        ,Sku              ,AltSku
            ,UOM              ,UOMQty           ,Qty
            ,QtyMoved         ,STATUS           ,DropID
            ,Loc              ,ID               ,PackKey
            ,UpdateSource     ,CartonGroup      ,CartonType
            ,ToLoc            ,DoReplenish      ,ReplenishZone
            ,DoCartonize      ,PickMethod       ,WaveKey
            ,EffectiveDate    ,TrafficCop       ,ArchiveCop
            ,OptimizeCop      ,ShipFlag         ,PickSlipNo
            ,Channel_ID   --SY01
            )
         SELECT @c_NewPickDetailKey  AS PickDetailKey
               ,CaseID           ,PickHeaderKey    ,OrderKey
               ,OrderLineNumber  ,Lot              ,Storerkey
               ,Sku              ,AltSku           ,UOM
               ,UOMQty           ,@n_QtyAlloc -  @n_ReplenQty
               ,QtyMoved         ,[STATUS]         ,DropID
               ,Loc              ,ID               ,PackKey
               ,UpdateSource     ,CartonGroup      ,CartonType
               ,ToLoc            ,DoReplenish      ,ReplenishZone
               ,DoCartonize      ,PickMethod       ,WaveKey
               ,EffectiveDate    ,TrafficCop       ,ArchiveCop
               ,'1'              ,ShipFlag         ,PickSlipNo
               ,Channel_ID   --SY01
         FROM   dbo.PickDetail WITH (NOLOCK)
         WHERE  PickDetailKey = @c_PickDetailKey

         UPDATE PickDetail WITH (ROWLOCK)
         SET Qty = @n_ReplenQty, TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @c_PickDetailKey

         SET @n_QtyAlloc =  @n_ReplenQty
      END -- IF @n_ReplenQty > @n_QtyAlloc

      SET @n_QtyAvaliableLOT = 0

      SELECT @n_QtyAvaliableLOT = SUM(Qty - QtyAllocated - QtyPicked)
      FROM LotxLocxID AS LLI WITH (NOLOCK)
      JOIN LOC AS LOC WITH(NOLOCK) ON LLI.LOC = LOC.LOC
      WHERE Storerkey = @c_StorerKey
      AND   SKU = @c_SKU
      AND   Facility = @c_Facility
      AND   LOT = @c_PickLOT
      AND   LOC.Status = 'OK'

      IF @n_QtyAvaliableLOT >= @n_QtyAlloc AND (@c_PickID <> @c_ToID OR @c_PickLOT <> @c_LOT)
      BEGIN
         IF @b_Debug = 1
         BEGIN
           PRINT '>>>  Update LOT, PickDetailKey:' + @c_PickDetailKey
           PRINT '      ID: ' + @c_ToID
           PRINT '      LOT: ' + @c_LOT + ', LOC: ' + @c_LOC
            PRINT '      ReplenQty: ' + CAST (@n_ReplenQty AS VARCHAR) +  ', QtyAlloc: ' + CAST(@n_QtyAlloc AS VARCHAR)
         END



         --IF LOT different, Swap to other same LOT Pickdetail records  WWANG01
        SET @n_SwapLotQty = @n_QtyAlloc

        WHILE @n_SwapLotQty > 0
        BEGIN
          SET @c_SwapPickDetailKey = ''
          SET @n_NewQtyAlloc = 0

           SELECT TOP 1
               @c_SwapPickDetailKey = P.PickDetailKey,
               @n_NewQtyAlloc  = P.Qty
           FROM  PICKDETAIL P WITH (NOLOCK)
           JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = P.OrderKey AND o.DocType='E'
           WHERE NOT EXISTS(SELECT 1 FROM PackTask AS PT WITH (NOLOCK)
                              WHERE PT.ReplenishmentGroup = @c_ReplenishmentGroup
                              AND   PT.OrderKey = P.OrderKey)
           AND   P.DoReplenish = 'N'
           AND   P.UOM = '7'
           AND   P.StorerKey = @c_StorerKey
           AND   ISNULL(P.CartonGroup,'') <> 'ReplenSwap'
           AND   P.Sku = @c_SKU
           AND   P.LOC = @c_LOC
           AND   P.LOT = @c_LOT
           AND   P.ID  = @c_ToID
           AND   P.Qty > 0
           AND   P.STATUS < '4'
           AND   P.ShipFlag NOT IN ('P','Y')
           ORDER BY PickdetailKey

         IF @c_SwapPickDetailKey <> ''
         BEGIN
            IF @b_Debug = 1
            BEGIN
              PRINT '  *** Exchange LOT/ID ***'
              PRINT '      With PickDetailKey: ' + @c_SwapPickDetailKey + ', To ID: ' + @c_ToID
              PRINT '      Qty: ' + CAST(@n_NewQtyAlloc AS VARCHAR(10))
            END

            IF @n_NewQtyAlloc > @n_SwapLotQty
            BEGIN
                  SET @c_NewSwapPickDetailKey = ''

                  EXECUTE dbo.nspg_GetKey
                     'PICKDETAILKEY',
                     10 ,
                     @c_NewSwapPickDetailKey  OUTPUT,
                     @b_success        OUTPUT,
                     @n_err            OUTPUT,
                     @c_errmsg         OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SET @n_Err = 63885
                     SET @c_ErrMsg = 'Get Pickdetail Key'
                     SEt @n_Continue = 3
                     GOTO EXIT_SP
                  END

                  IF @b_Debug = 1
                  BEGIN
                    PRINT '  *** Split PickDetail ***'
                    PRINT '      New PickDetailKey: ' + @c_NewSwapPickDetailKey + ', Qty: '
                          + CAST((@n_NewQtyAlloc -  @n_SwapLotQty) AS VARCHAR(10))
                  END

                  INSERT INTO dbo.PICKDETAIL
                    (
                      PickDetailKey    ,CaseID           ,PickHeaderKey
                     ,OrderKey         ,OrderLineNumber  ,Lot
                     ,Storerkey        ,Sku              ,AltSku
                     ,UOM              ,UOMQty           ,Qty
                     ,QtyMoved         ,STATUS           ,DropID
                     ,Loc              ,ID               ,PackKey
                     ,UpdateSource     ,CartonGroup      ,CartonType
                     ,ToLoc            ,DoReplenish      ,ReplenishZone
                     ,DoCartonize      ,PickMethod       ,WaveKey
                     ,EffectiveDate    ,TrafficCop       ,ArchiveCop
                     ,OptimizeCop      ,ShipFlag         ,PickSlipNo
                     ,Channel_ID   --SY01
                    )
                  SELECT @c_NewSwapPickDetailKey  AS PickDetailKey
                        ,CaseID           ,PickHeaderKey    ,OrderKey
                        ,OrderLineNumber  ,Lot              ,Storerkey
                        ,Sku              ,AltSku           ,UOM
                        ,UOMQty           ,@n_NewQtyAlloc -  @n_SwapLotQty
                        ,QtyMoved         ,[STATUS]         ,DropID
                        ,Loc              ,ID               ,PackKey
                        ,UpdateSource     ,CartonGroup      ,CartonType
                        ,ToLoc            ,DoReplenish      ,ReplenishZone
                        ,DoCartonize      ,PickMethod       ,WaveKey
                        ,EffectiveDate    ,TrafficCop       ,ArchiveCop
                        ,'1'              ,ShipFlag         ,PickSlipNo
                        ,Channel_ID   --SY01
                  FROM   dbo.PickDetail WITH (NOLOCK)
                  WHERE  PickDetailKey = @c_SwapPickDetailKey

                  UPDATE PickDetail WITH (ROWLOCK)
                  SET Qty = @n_SwapLotQty, TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME()
                  WHERE PickDetailKey = @c_SwapPickDetailKey

                  SET @n_NewQtyAlloc =  @n_SwapLotQty

              END -- IF @n_NEwQtyAlloc > @n_SwapLotQty


               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET ID = @c_PickID, LOT=@c_PickLOT, CartonType = @c_LOT, CartonGroup = 'ReplenSwap', EditDate = GETDATE(), EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @c_SwapPickDetailKey


            SET @n_SwapLotQty = @n_SwapLotQty - @n_NewQtyAlloc

           IF @n_SwapLotQty <= 0
              BREAK
        END -- IF @c_SwapPickDetailKey <> ''

        ELSE
            BREAK

        END --WHILE @n_ReplenQty > 0   --IF LOT different, Swap to other same LOT Pickdetail records- WWANG01

      SET @n_QtyAvaliableLOT = 0

      SELECT @n_QtyAvaliableLOT = SUM(Qty - QtyAllocated - QtyPicked)
       FROM LotxLocxID AS LLI WITH (NOLOCK)
       JOIN LOC AS LOC WITH(NOLOCK) ON LLI.LOC = LOC.LOC
       WHERE Storerkey = @c_StorerKey
       AND   SKU = @c_SKU
       AND   Facility = @c_Facility
       AND   LOT = @c_LOT
       AND   LOC.Status = 'OK'

       IF @n_QtyAvaliableLOT >= @n_QtyAlloc
       BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET    ID = @c_ToID,
                LOT = @c_LOT,
                CartonType = @c_PickLot,
                EditDate = GETDATE(),
                EditWho = SUSER_SNAME()
          WHERE PickDetailKey = @c_PickDetailKey

        END

      END


      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET    CartonGroup = 'ReplenSwap',
             TrafficCop = NULL,
             EditDate = GETDATE(),
             EditWho = SUSER_SNAME()
      WHERE PickDetailKey = @c_PickDetailKey

      SET @n_ReplenQty = @n_ReplenQty - @n_QtyAlloc

      IF @n_ReplenQty <= 0
       BREAK

   FETCH NEXT FROM CUR_OFFSET_PICKDETAIL INTO @c_PickDetailKey, @c_PickLOT, @c_PickID, @n_QtyAlloc
   END
   CLOSE CUR_OFFSET_PICKDETAIL
   DEALLOCATE CUR_OFFSET_PICKDETAIL

   IF @n_RemainReplenQty > 0
   BEGIN
      IF @b_Debug = 1
      BEGIN
        PRINT '>>>   ReplenishmentKey:' + @c_ReplenishmentKey +
              ', Replen Qty:' + CAST(@n_RemainReplenQty AS VARCHAR(10))
        PRINT '      SKU: ' + @c_SKU
        PRINT '      LOT: ' + @c_LOT + ', LOC: ' + @c_LOC
      END

    SET @n_QtyAvaliable = 0
    --SET @c_ToID = ''

    SELECT TOP 1
        @n_QtyAvaliable = SL.Qty - SL.QtyAllocated - SL.QtyPicked
    FROM SKUxLOC AS SL WITH(NOLOCK)
    WHERE SL.StorerKey = @c_StorerKey
    AND SL.Sku = @c_SKU
    AND SL.Loc = @c_LOC

      IF @b_Debug = 1
      BEGIN
        PRINT '      Available Qty:' + CAST(@n_QtyAvaliable AS VARCHAR(10)) +
              ', To ID:' + @c_ToID
      END

    IF @n_QtyAvaliable >= @n_RemainReplenQty
       GOTO EXIT_SP

    IF @n_QtyAvaliable > 0
       SET @n_RemainReplenQty = @n_RemainReplenQty - @n_QtyAvaliable

    WHILE @n_RemainReplenQty > 0
    BEGIN
        SET @c_PickDetailKey = ''
        SET @c_PickLOT = ''
        SET @c_PickID = ''
         SET @n_QtyAlloc = 0

        -- swap with other batch
         IF @c_ForceAllocLottable = '1'
         BEGIN
            SELECT @c_SQLSelect =
          N'SELECT TOP 1
               @c_PickDetailKey = PD.PickDetailKey,
               @n_QtyAlloc      = PD.Qty,
               @c_PickLOT       = PD.LOT,
               @c_PickID        = PD.ID
            FROM PICKDETAIL AS PD WITH (NOLOCK)
            JOIN LOTATTRIBUTE AS LA WITH (NOLOCK) ON LA.LOT = PD.LOT
            JOIN ORDERS AS O WITH(NOLOCK) ON O.OrderKey = PD.OrderKey AND O.DocType=''E''
           WHERE NOT EXISTS(SELECT 1 FROM PackTask AS PT WITH (NOLOCK)
                              WHERE PT.ReplenishmentGroup = @c_ReplenishmentGroup
                              AND   PT.OrderKey = PD.OrderKey)
           AND   PD.DoReplenish = ''N''
            AND   PD.StorerKey = @c_StorerKey
          AND   PD.Sku = @c_SKU
           AND   PD.LOC = @c_LOC
           AND   PD.UOM = ''7''
           AND   PD.Qty > 0
            AND   PD.STATUS < ''4''
            AND   PD.ShipFlag NOT IN (''P'',''Y'')  ' +
            CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') <> '' AND CHARINDEX('LOTTABLE01', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable01 = @c_Lottable01 ' ELSE '' END +
            CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') <> '' AND CHARINDEX('LOTTABLE02', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable02 = @c_Lottable02 ' ELSE '' END +
            CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') <> '' AND CHARINDEX('LOTTABLE03', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable03 = @c_Lottable03 ' ELSE '' END +
            CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') <> '' AND CHARINDEX('LOTTABLE06', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable06 = @c_Lottable06 ' ELSE '' END +
            CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') <> '' AND CHARINDEX('LOTTABLE07', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable07 = @c_Lottable07 ' ELSE '' END +
            CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') <> '' AND CHARINDEX('LOTTABLE08', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable08 = @c_Lottable08 ' ELSE '' END +
            CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') <> '' AND CHARINDEX('LOTTABLE09', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable09 = @c_Lottable09 ' ELSE '' END +
            CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') <> '' AND CHARINDEX('LOTTABLE10', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable10 = @c_Lottable10 ' ELSE '' END +
            CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') <> '' AND CHARINDEX('LOTTABLE11', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable11 = @c_Lottable11 ' ELSE '' END +
            CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') <> '' AND CHARINDEX('LOTTABLE12', @c_ForceLottableList) > 0 THEN 'AND LA.Lottable12 = @c_Lottable12 ' ELSE '' END +
            N'  ORDER BY CASE WHEN PD.LOT = @c_LOT AND PD.ID = @c_ToID THEN 1
                               WHEN PD.LOT = @c_LOT AND PD.ID <> @c_ToID THEN 2
                               ELSE 3
                          END    '

            EXEC sp_executesql @c_SQLSelect,
               N'@c_ReplenishmentGroup NVARCHAR(10)
               , @c_StorerKey  NVARCHAR(15)
               , @c_LOC        NVARCHAR(10)
               , @c_SKU        NVARCHAR(20)
               , @c_LOT        NVARCHAR(10)
               , @c_ToID     NVARCHAR(18)
               , @c_Lottable01 NVARCHAR(18)
               , @c_Lottable02 NVARCHAR(18)
               , @c_Lottable03 NVARCHAR(18)
               , @d_Lottable04 DATETIME
               , @c_Lottable06 NVARCHAR(30)
               , @c_Lottable07 NVARCHAR(30)
               , @c_Lottable08 NVARCHAR(30)
               , @c_Lottable09 NVARCHAR(30)
               , @c_Lottable10 NVARCHAR(30)
               , @c_Lottable11 NVARCHAR(30)
               , @c_Lottable12 NVARCHAR(30)
               , @c_PickDetailKey NVARCHAR(10) OUTPUT
               , @n_QtyAlloc      INT          OUTPUT
               , @c_PickLOT       NVARCHAR(10) OUTPUT
                ,@c_PickID        NVARCHAR(10) OUTPUT'
               , @c_ReplenishmentGroup
               , @c_StorerKey
               , @c_LOC
               , @c_SKU
               , @c_LOT
               , @c_ToID
               , @c_Lottable01
               , @c_Lottable02
               , @c_Lottable03
               , @d_Lottable04
               , @c_Lottable06
               , @c_Lottable07
               , @c_Lottable08
               , @c_Lottable09
               , @c_Lottable10
               , @c_Lottable11
               , @c_Lottable12
               , @c_PickDetailKey OUTPUT
               , @n_QtyAlloc OUTPUT
               , @c_PickLOT  OUTPUT
               , @c_PickID   OUTPUT
         END
         ELSE
         BEGIN
           SELECT TOP 1
               @c_PickDetailKey = P.PickDetailKey,
               @n_QtyAlloc  = P.Qty,
               @c_PickLOT   = P.LOT
           FROM  PICKDETAIL P WITH (NOLOCK)
           JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = P.OrderKey AND o.DocType='E'
           WHERE NOT EXISTS(SELECT 1 FROM PackTask AS PT WITH (NOLOCK)
                              WHERE PT.ReplenishmentGroup = @c_ReplenishmentGroup
                              AND   PT.OrderKey = P.OrderKey)
           AND   P.DoReplenish = 'N'
            AND   P.StorerKey = @c_StorerKey
          AND   P.Sku = @c_SKU
           AND   P.LOC = @c_LOC
           AND   P.UOM = '7'
           AND   P.Qty > 0
            AND   P.STATUS < '4'
            AND   P.ShipFlag NOT IN ('P','Y')
           ORDER BY CASE WHEN P.LOT = @c_LOT AND P.ID = @c_ToID THEN 1
                         WHEN P.LOT = @c_LOT AND P.ID <> @c_ToID THEN 2
                         ELSE 3
                    END
         END


         IF @c_PickDetailKey <> ''
         BEGIN
            IF @b_Debug = 1
            BEGIN
               PRINT '  *** Exchange UOM ***'
              PRINT '      With PickDetailKey: ' + @c_PickDetailKey + ', To ID: ' + @c_ToID
              PRINT '      Qty: ' + CAST(@n_QtyAlloc AS VARCHAR(10))
            END

            IF @n_QtyAlloc > @n_RemainReplenQty
            BEGIN
                  SET @c_NewPickDetailKey = ''

                  EXECUTE dbo.nspg_GetKey
                     'PICKDETAILKEY',
                     10 ,
                     @c_NewPickDetailKey  OUTPUT,
                     @b_success        OUTPUT,
                     @n_err            OUTPUT,
                     @c_errmsg         OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SET @n_Err = 63885
                     SET @c_ErrMsg = 'Get Pickdetail Key'
                     SEt @n_Continue = 3
                     GOTO EXIT_SP
                  END

                  IF @b_Debug = 1
                  BEGIN
                    PRINT '  *** Split PickDetail ***'
                    PRINT '      New PickDetailKey: ' + @c_NewPickDetailKey + ', Qty: '
                          + CAST((@n_QtyAlloc -  @n_RemainReplenQty) AS VARCHAR(10))
                  END

                  INSERT INTO dbo.PICKDETAIL
                    (
                      PickDetailKey    ,CaseID           ,PickHeaderKey
                     ,OrderKey         ,OrderLineNumber  ,Lot
                     ,Storerkey        ,Sku              ,AltSku
                     ,UOM              ,UOMQty           ,Qty
                     ,QtyMoved         ,STATUS           ,DropID
                     ,Loc              ,ID               ,PackKey
                     ,UpdateSource     ,CartonGroup      ,CartonType
                     ,ToLoc            ,DoReplenish      ,ReplenishZone
                     ,DoCartonize      ,PickMethod       ,WaveKey
                     ,EffectiveDate    ,TrafficCop       ,ArchiveCop
                     ,OptimizeCop      ,ShipFlag         ,PickSlipNo
                     ,Channel_ID   --SY01
                    )
                  SELECT @c_NewPickDetailKey  AS PickDetailKey
                        ,CaseID           ,PickHeaderKey    ,OrderKey
                        ,OrderLineNumber  ,Lot              ,Storerkey
                        ,Sku              ,AltSku           ,UOM
                        ,UOMQty           ,@n_QtyAlloc -  @n_RemainReplenQty
                        ,QtyMoved         ,[STATUS]         ,DropID
                        ,Loc              ,ID               ,PackKey
                        ,UpdateSource     ,CartonGroup      ,CartonType
                        ,ToLoc            ,DoReplenish      ,ReplenishZone
                        ,DoCartonize      ,PickMethod       ,WaveKey
                        ,EffectiveDate    ,TrafficCop       ,ArchiveCop
                        ,'1'              ,ShipFlag         ,PickSlipNo
                        ,Channel_ID   --SY01
                  FROM   dbo.PickDetail WITH (NOLOCK)
                  WHERE  PickDetailKey = @c_PickDetailKey

                  UPDATE PickDetail WITH (ROWLOCK)
                     SET Qty = @n_RemainReplenQty, TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME()
                  WHERE PickDetailKey = @c_PickDetailKey

                  SET @n_QtyAlloc =  @n_RemainReplenQty
            END -- IF @n_QtyAlloc > @n_RemainReplenQty

            SET @n_QtyAvaliableLOT = 0

            SELECT @n_QtyAvaliableLOT = SUM(Qty - QtyAllocated - QtyPicked)
            FROM LotxLocxID AS LLI WITH (NOLOCK)
            JOIN LOC AS LOC WITH(NOLOCK) ON LLI.LOC = LOC.LOC
            WHERE Storerkey = @c_StorerKey
            AND   SKU = @c_SKU
            AND   Facility = @c_Facility
            AND   LOT = @c_LOT
            AND   ID = @c_ToID
            AND   LOC.Status = 'OK'

            IF @n_QtyAvaliableLOT >= @n_QtyAlloc AND (@c_PickID <> @c_ToID OR  @c_PickLOT <> @c_LOT)
            BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
                   SET UOM = '6', ID = @c_ToID, LOT=@c_LOT, EditDate = GETDATE(), EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @c_PickDetailKey
            END
            ELSE
            BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
                   SET UOM = '6', TrafficCop = NULL, EditDate = GETDATE(), EditWho = SUSER_SNAME()
               WHERE PickDetailKey = @c_PickDetailKey
            END

            SET @n_RemainReplenQty = @n_RemainReplenQty - @n_QtyAlloc

           IF @n_RemainReplenQty <= 0
              BREAK
         END -- IF @c_PickDetailKey <> ''
         ELSE
            BREAK
    END -- WHILE @n_RemainReplenQty > 0
   END -- IF @n_RemainReplenQty > 0

   EXIT_SP:
END

GO