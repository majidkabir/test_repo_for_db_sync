SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspIDSAutoMatePOGen                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspIDSAutoMatePOGen] AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_SKU        NVARCHAR(20),
   @c_StorerKey  NVARCHAR(15),
   @n_CurrADS    float,       -- Average Daily Sales
   @n_QtyExpected int,
   @n_QtyReceived int,
   @n_DelLeadTime int,
   @n_ProcDays    int,
   @n_IncrementOrderQty int,
   @c_IncrementOrderUOM NVARCHAR(10),
   @n_LastADS           float,   -- Last Average Daily Sales
   @n_FlucRate          float,   -- Fluctuation Rate
   @n_QtyAvailable      int,
   @n_ADSFactor         int,     -- ADS Fctor
   @n_MaxFluctuation    int,
   @n_SafetyLevel       int,
   @n_ProcurementDays   int,
   @n_IncrementalOrderQty   int,
   @c_IncrementalOrderUOM   NVARCHAR(10),
   @n_QtyDelivered          int,
   @n_A                     float,
   @n_B                     float,
   @n_X                     float,
   @n_Y                     float,
   @n_Z                     float
   DECLARE SKU_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SKU.STORERKEY, SKU.SKU
   FROM   SKU (NOLOCK), SKUCONFIG (NOLOCK)
   WHERE  SKU.STORERKEY = SKUCONFIG.STORERKEY
   AND    SKU.SKU = SKUCONFIG.SKU
   AND    SKUCONFIG.ConfigType = 'POAUTOMATE'
   AND    SKUCONFIG.DATA = 'Y'
   OPEN SKU_CUR
   FETCH NEXT FROM SKU_CUR INTO @c_StorerKey, @c_SKU
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Calculated Qty Available
      SELECT @n_QtyAvailable = 0
      SELECT @n_QtyAvailable = SUM(LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED)
      FROM LOTxLOCxID (NOLOCK), LOC (NOLOCK), ID (NOLOCK)
      WHERE LOTxLOCxID.Loc = LOC.LOC
      AND LOTxLOCxID.ID = ID.ID
      AND ID.Status <> "HOLD"
      AND LOC.Locationflag <> "HOLD"
      AND LOC.Locationflag <> "DAMAGE"
      AND LOC.Status <> "HOLD"
      AND LOTxLOCxID.StorerKey = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU
      IF @n_QtyAvailable IS NULL
      SELECT @n_QtyAvailable = 0
      -- Get Total Qty Expected
      SELECT @n_QtyExpected = 0
      SELECT @n_QtyExpected = SUM( QtyExpected - QtyReceived )
      FROM   RECEIPTDETAIL (NOLOCK)
      WHERE  StorerKey = @c_StorerKey
      AND    SKU = @c_SKU
      AND    QtyExpected > QtyReceived
      IF @n_QtyExpected IS NULL
      SELECT @n_QtyExpected = 0
      -- Calculated Average Daily Sales
      -- Retrieve ADS Factor
      SELECT @n_ADSFactor = 0
      SELECT @n_ADSFactor = CAST(SKUCONFIG.Data as int)
      FROM   SKUCONFIG (NOLOCK)
      WHERE  SKUCONFIG.STORERKEY = @c_StorerKey
      AND    SKUCONFIG.SKU = @c_SKU
      AND    SKUCONFIG.ConfigType = 'ADSFACTOR'
      IF @n_ADSFactor IS NULL
      SELECT @n_ADSFactor = 0
      -- Retrieve ADS Factor
      SELECT @n_MaxFluctuation = 0
      SELECT @n_MaxFluctuation = CAST(SKUCONFIG.Data as int)
      FROM   SKUCONFIG (NOLOCK)
      WHERE  SKUCONFIG.STORERKEY = @c_StorerKey
      AND    SKUCONFIG.SKU = @c_SKU
      AND    SKUCONFIG.ConfigType = 'MAXFLUC'
      IF @n_MaxFluctuation IS NULL
      SELECT @n_MaxFluctuation = 0
      -- Calculate QtyDelivered in no of Days specified in ADSFactor
      SELECT @n_SafetyLevel = 0
      SELECT @n_SafetyLevel = CAST(SKUCONFIG.Data as int)
      FROM   SKUCONFIG (NOLOCK)
      WHERE  SKUCONFIG.STORERKEY = @c_StorerKey
      AND    SKUCONFIG.SKU = @c_SKU
      AND    SKUCONFIG.ConfigType = 'SAFETYLV'
      IF @n_SafetyLevel IS NULL
      SELECT @n_SafetyLevel = 0
      SELECT @n_DelLeadTime = 0
      SELECT @n_DelLeadTime = CAST(SKUCONFIG.Data as int)
      FROM   SKUCONFIG (NOLOCK)
      WHERE  SKUCONFIG.STORERKEY = @c_StorerKey
      AND    SKUCONFIG.SKU = @c_SKU
      AND    SKUCONFIG.ConfigType = 'DELLEADTM'
      IF @n_DelLeadTime IS NULL
      SELECT @n_DelLeadTime = 0
      SELECT @n_ProcurementDays = 0
      SELECT @n_ProcurementDays = CAST(SKUCONFIG.Data as int)
      FROM   SKUCONFIG (NOLOCK)
      WHERE  SKUCONFIG.STORERKEY = @c_StorerKey
      AND    SKUCONFIG.SKU = @c_SKU
      AND    SKUCONFIG.ConfigType = 'PROCDAYS'
      IF @n_ProcurementDays IS NULL
      SELECT @n_ProcurementDays = 0
      SELECT @n_IncrementalOrderQty = 1
      SELECT @n_IncrementalOrderQty = CAST(SKUCONFIG.Data as int)
      FROM   SKUCONFIG (NOLOCK)
      WHERE  SKUCONFIG.STORERKEY = @c_StorerKey
      AND    SKUCONFIG.SKU = @c_SKU
      AND    SKUCONFIG.ConfigType = 'INCORDQTY'
      IF @n_IncrementalOrderQty IS NULL
      SELECT @n_IncrementalOrderQty = 1
      SELECT @c_IncrementalOrderUOM = CAST(SKUCONFIG.Data as int)
      FROM   SKUCONFIG (NOLOCK)
      WHERE  SKUCONFIG.STORERKEY = @c_StorerKey
      AND    SKUCONFIG.SKU = @c_SKU
      AND    SKUCONFIG.ConfigType = 'INCORDUOM'
      IF @c_IncrementalOrderUOM IS NULL
      SELECT @c_IncrementalOrderUOM = 0
      SELECT @n_LastADS = 0
      SELECT @n_LastADS = CAST(SKUCONFIG.Data as float)
      FROM   SKUCONFIG (NOLOCK)
      WHERE  SKUCONFIG.STORERKEY = @c_StorerKey
      AND    SKUCONFIG.SKU = @c_SKU
      AND    SKUCONFIG.ConfigType = 'LASTADS'
      IF @n_LastADS is NULL
      BEGIN
         SELECT @n_LastADS = 0
      END
      -- Calculate ADS
      SELECT @n_QtyDelivered = SUM(Qty)
      FROM PickDetail (NOLOCK)
      WHERE  StorerKey = @c_StorerKey
      AND    SKU = @c_SKU
      AND    EditDate Between DateAdd( day, @n_ADSFactor * -1, CAST( CONVERT(char(20), GetDate(), 106) AS Datetime ) ) AND
      CAST( CONVERT(char(20), GetDate(), 106) AS Datetime )
      AND    Status = '9'
      IF @n_QtyDelivered IS NULL
      SELECT @n_QtyDelivered = 0
      SELECT @n_CurrADS = @n_QtyDelivered / @n_ADSFactor
      IF @n_CurrADS IS NULL OR @n_CurrADS = 0
      SELECT @n_CurrADS = 1
      IF @n_LastADS > 0
      SELECT @n_FlucRate = @n_CurrADS / @n_LastADS
   ELSE
      SELECT @n_FlucRate = 1
      SELECT @n_A = 0
      SELECT @n_B = 0
      SELECT @n_A = ( @n_QtyAvailable + @n_QtyExpected ) / ( @n_CurrADS * @n_FlucRate )
      IF @n_A IS NULL
      SELECT @n_A = 0
      SELECT @n_B = ( @n_DelLeadTime + @n_SafetyLevel + @n_ProcurementDays )
      IF @n_A <= @n_B
      BEGIN
         SELECT @n_X = ( @n_B * @n_CurrADS * @n_FlucRate ) - ( @n_QtyAvailable + @n_QtyExpected )
         SELECT @n_Y = @n_X / ( @n_IncrementalOrderQty * PACK.CaseCnt )
         FROM   SKU (NOLOCK), PACK (NOLOCK)
         WHERE  SKU.StorerKey = @c_StorerKey
         AND    SKU.SKU = @c_SKU
         AND    SKU.PackKey = PACK.PackKey
         IF @n_Y > 0 AND @n_Y < 1
         BEGIN
            SELECT @n_Z = ( @n_IncrementalOrderQty * PACK.CaseCnt )
            FROM   SKU (NOLOCK), PACK (NOLOCK)
            WHERE  SKU.StorerKey = @c_StorerKey
            AND    SKU.SKU = @c_SKU
            AND    SKU.PackKey = PACK.PackKey
         END
      ELSE
         BEGIN
            IF @n_Y >= 1
            BEGIN
               SELECT @n_Z = ( ROUND( @n_Y, 0 ) * @n_IncrementalOrderQty * PACK.CaseCnt )
               FROM   SKU (NOLOCK), PACK (NOLOCK)
               WHERE  SKU.StorerKey = @c_StorerKey
               AND    SKU.SKU = @c_SKU
               AND    SKU.PackKey = PACK.PackKey
            END
         END
      END -- IF @n_A <= @n_B
   ELSE
      BEGIN
         SELECT @n_Z = 0
      END
      /*
      IF @n_Z > 0
      BEGIN
      SELECT @c_SKU "SKU", @n_Z
      END
      */
      SELECT @c_SKU "SKU", @n_A "A", @n_B "B", @n_CurrADS '@n_CurrADS', @n_FlucRate '@n_FlucRate', @n_QtyAvailable '@n_QtyAvailable',
      @n_QtyExpected '@n_QtyExpected', @n_QtyDelivered '@n_QtyDelivered', @n_ADSFactor '@n_ADSFactor', @n_Z "Z"
      FETCH NEXT FROM SKU_CUR INTO @c_StorerKey, @c_SKU
   END -- WHILE
   DEALLOCATE SKU_CUR
END -- Procedure


GO