SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure:  nspInventoryHoldWrapper                           */
/* Creation Date: 18-Aug-2009                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.7                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 18-Aug-2009  NJOW01    1.1   SOS#144863. Allow InvnetoryHold.status  */
/*                              can be editable once it is on-hold      */
/* 15-Jul-2010  KHLim     1.2   Replace USER_NAME to sUSER_sName        */
/* 15-Jul-2010  SHONG     1.3   Bug Fixing                              */
/* 03-Apr-2013  SHONG     1.4   Should not release for other Lottable   */
/*                              that still on-hold. (Shong01)           */
/* 26-Apr-2013  NJOW02    1.5   274331-Allow update remark              */
/* 28-Oct-2013  MCTang    1.6   Add Configkey = INVHSTSLOG (MC01)       */
/* 13-Aug-2014  TKLIM     1.7   Added Lottables 06-15                   */
/* 07-Nov-2014  TKLIM     1.7   Validation for Hold by Lottable (TK01)  */
/* 27-Oct-2015  Leong     1.8   SOS# 355593 - Bug Fix.                  */
/* 20-Apr-2018  SHONG     1.9   Channel Management (SWT01)              */ 
/*----------------------------------------------------------------------*/
/* 27-Feb-2019  YokeBeen  1.4   WMS7973 - Revised Trigger Point values. */
/*                              Differentiate new records - (YokeBeen01)*/
/* 06-May-2019  WLChooi   1.5   WMS-8866 - Add Lottable04,05,13,14,15   */
/* 23-JUL-2019  Wan01     1.6   ChannelInventoryMgmt use nspGetRight2   */
/* 01-DEC-2021  Wan02     1.7   Fixed. Remark Delete from #LotByBatch & */
/*                              Not to Rollback if @@Trancount not 1    */
/* 01-DEC-2021  Wan02     1.7   DevOps Combine Script                   */
/* 21-JUL-2022  NJOW03    1.8   WMS-20297 allow inventory hold in channel*/
/*                              management by config.                   */
/************************************************************************/
CREATE PROC [dbo].[nspInventoryHoldWrapper]
     @c_lot          NVARCHAR(10)
   , @c_Loc          NVARCHAR(10)
   , @c_ID           NVARCHAR(18)
   , @c_StorerKey    NVARCHAR(15) -- Added by Shong 11.Apr.2002
   , @c_SKU          NVARCHAR(20) -- Added by Shong 11.Apr.2002
   , @c_Lottable01   NVARCHAR(18)
   , @c_Lottable02   NVARCHAR(18)
   , @c_Lottable03   NVARCHAR(18)
   , @dt_Lottable04  DATETIME -- IDSV5 - Leo (For V5.1 Feature; remark by Ricky)
   , @dt_Lottable05  DATETIME -- IDSV5 - LEo (For V5.1 Feature; remark by Ricky)
   , @c_Lottable06   NVARCHAR(30)   = ''
   , @c_Lottable07   NVARCHAR(30)   = ''
   , @c_Lottable08   NVARCHAR(30)   = ''
   , @c_Lottable09   NVARCHAR(30)   = ''
   , @c_Lottable10   NVARCHAR(30)   = ''
   , @c_Lottable11   NVARCHAR(30)   = ''
   , @c_Lottable12   NVARCHAR(30)   = ''
   , @dt_Lottable13  DATETIME       = NULL
   , @dt_Lottable14  DATETIME       = NULL
   , @dt_Lottable15  DATETIME       = NULL
   , @c_Status       NVARCHAR(10)
   , @c_Hold         NVARCHAR(1)
   , @b_success      INT            OUTPUT
   , @n_Err          INT            OUTPUT
   , @c_Errmsg       NVARCHAR(250)  OUTPUT
   , @c_Remark       NVARCHAR(260)  = '' -- SOS89194
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue                INT
          ,@n_starttcnt               INT            -- bring forward tran count
          ,@b_debug                   INT
          ,@d_CurrentDatetime         DATETIME       -- SOS89194
          ,@c_CurrentUser             NVARCHAR(18)   -- SOS89194

   --NJOW01
   DECLARE @c_CurrHold                NVARCHAR(1)
          ,@n_HoldCnt                 INT
          ,@n_ReleaseCnt              INT
          ,@c_Hold_Chg                NVARCHAR(1)
          ,@c_Key2                    NVARCHAR(5)     --(MC01)
          ,@c_TransmitLogKey          NVARCHAR(10)    --(MC01)
          ,@c_Exec_Cur                NVARCHAR(4000)  --(MC01)
          ,@c_ChannelInventoryMgmt    NVARCHAR(10) = '0' -- (SWT01)            
   
   --NJOW03       
   DECLARE @c_Option1                 NVARCHAR(50)    
          ,@c_Option2                 NVARCHAR(50)  
          ,@c_Option3                 NVARCHAR(50)  
          ,@c_Option4                 NVARCHAR(50)  
          ,@c_Option5                 NVARCHAR(4000)      

   DECLARE @c_InventoryHoldKey        NVARCHAR(10)

   SELECT @n_continue = 1
         ,@b_debug = 0

   SELECT @n_starttcnt        = @@TRANCOUNT
   SELECT @d_CurrentDatetime  = GETDATE()
         ,@c_CurrentUser      = sUSER_sNAME() -- SOS89194

   -- FBR049 IDSHK 16/08/2001 - Hold By Batch Number.
   -- When holdig by batch, use the following logic:-
   -- Perform a loop to search for the matching lot based on the Lottables and pass it to nspInventoryHold stored procedure.
   -- If there are 10 lot number found, there will be 10 records inserted into inventoryhold table.  On top of that,
   -- there will be one more record with only the Lottables values, the lot, ID and Location will be ''
   DECLARE @b_HoldByBatch INT
   SELECT @b_HoldByBatch = 0

   BEGIN TRAN

   IF ISNULL(RTrim(@c_Lottable01),'') = ''   SELECT @c_Lottable01 = ''
   IF ISNULL(RTrim(@c_Lottable02),'') = ''   SELECT @c_Lottable02 = ''
   IF ISNULL(RTrim(@c_Lottable03),'') = ''   SELECT @c_Lottable03 = ''
   IF ISNULL(RTrim(@c_Lottable06),'') = ''   SELECT @c_Lottable06 = ''
   IF ISNULL(RTrim(@c_Lottable07),'') = ''   SELECT @c_Lottable07 = ''
   IF ISNULL(RTrim(@c_Lottable08),'') = ''   SELECT @c_Lottable08 = ''
   IF ISNULL(RTrim(@c_Lottable09),'') = ''   SELECT @c_Lottable09 = ''
   IF ISNULL(RTrim(@c_Lottable10),'') = ''   SELECT @c_Lottable10 = ''
   IF ISNULL(RTrim(@c_Lottable11),'') = ''   SELECT @c_Lottable11 = ''
   IF ISNULL(RTrim(@c_Lottable12),'') = ''   SELECT @c_Lottable12 = ''
   IF ISNULL(RTrim(@c_storerkey),'') = ''    SELECT @c_storerkey = ''

   IF RTrim(@c_sku) IS NULL
      SELECT @c_sku = ''

   -- IF RTrim(@c_exec_whereclause),'') <> ''
   IF    (LEN(@c_Lottable01)>0)
      OR (LEN(@c_Lottable02)>0)
      OR (LEN(@c_Lottable03)>0)
      OR (LEN(@c_Lottable06)>0)
      OR (LEN(@c_Lottable07)>0)
      OR (LEN(@c_Lottable08)>0)
      OR (LEN(@c_Lottable09)>0)
      OR (LEN(@c_Lottable10)>0)
      OR (LEN(@c_Lottable11)>0)
      OR (LEN(@c_Lottable12)>0)
      OR (
            @dt_Lottable04 IS NOT NULL
            AND CONVERT(NVARCHAR(8) ,@dt_Lottable04 ,112) <> '19000101'
         )
      OR (
            @dt_Lottable05 IS NOT NULL
            AND CONVERT(NVARCHAR(8) ,@dt_Lottable05 ,112) <> '19000101'
         )
      OR (
            @dt_Lottable13 IS NOT NULL
            AND CONVERT(NVARCHAR(8) ,@dt_Lottable13 ,112) <> '19000101'
         )
      OR (
            @dt_Lottable14 IS NOT NULL
            AND CONVERT(NVARCHAR(8) ,@dt_Lottable14 ,112) <> '19000101'
         )
      OR (
            @dt_Lottable15 IS NOT NULL
            AND CONVERT(NVARCHAR(8) ,@dt_Lottable15 ,112) <> '19000101'
         )
   BEGIN
      SELECT @b_HoldByBatch = 1 -- , @c_exec_whereclause = RTrim(@c_exec_whereclause)
      
      -- SWT01
      SET @c_ChannelInventoryMgmt = '0'
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspGetRight2 --(Wan01) 
          @c_Facility  = '',
          @c_StorerKey = @c_StorerKey,        -- Storer
          @c_sku       = '',                  -- Sku
          @c_ConfigKey = 'ChannelInventoryMgmt',  -- ConfigKey
          @b_Success   = @b_success    OUTPUT,
          @c_authority = @c_ChannelInventoryMgmt  OUTPUT,
          @n_err       = @n_Err        OUTPUT,
          @c_errmsg    = @c_ErrMsg     OUTPUT,                            
          @c_Option1   = @c_Option1    OUTPUT,  --NJOW03
          @c_Option2   = @c_Option2    OUTPUT,
          @c_Option3   = @c_Option3    OUTPUT,
          @c_Option4   = @c_Option4    OUTPUT,
          @c_Option5   = @c_Option5    OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_ErrMsg = 'nspInventoryHoldWrapper:' + ISNULL(RTRIM(@c_ErrMsg),'')
         END
      END               
      IF @c_ChannelInventoryMgmt = '1'
         AND dbo.fnc_GetParamValueFromString('@c_AllowInvHoldInChannelMgmt', @c_Option5, 'N') <> 'Y'  --NJOW03
      BEGIN
         SELECT @n_continue = 3
         SELECT @b_Success = 0
         SELECT @n_Err = 60010
         SELECT @c_Errmsg = 'Inventory Hold Not allow for Channel Management Customer. [nspInventoryHoldWrapper]'
         GOTO EXIT_SP 
      END
            
      CREATE TABLE #LotByBatch
      (
         LOT               NVARCHAR(10)
        ,InventoryHoldKey  NVARCHAR(10)
      )
      -- check is the Lottables already been hold before?

      DECLARE @c_Exec_Str NVARCHAR(4000)

      SELECT @c_Exec_Str =
               ' INSERT INTO #LotByBatch ' +
               ' SELECT InventoryHold.LOT, InventoryHoldKey ' +
               ' FROM   InventoryHold (NOLOCK) ' +
               ' JOIN   LotAttribute WITH (NOLOCK) ON (InventoryHold.LOT = LOTAttribute.LOT) ' +
               ' WHERE  LotAttribute.StorerKey = ''' + RTrim(@c_StorerKey) + ''' ' +
               ' AND    LotAttribute.SKU = ''' + RTrim(@c_SKU) + ''''

      IF ISNULL(RTrim(@c_Lottable01),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable01 = ''' + @c_Lottable01 + ''''
      IF ISNULL(RTrim(@c_Lottable02),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable02 = ''' + @c_Lottable02 + ''''
      IF ISNULL(RTrim(@c_Lottable03),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable03 = ''' + @c_Lottable03 + ''''
      IF ISNULL(RTrim(@c_Lottable06),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable06 = ''' + @c_Lottable06 + ''''
      IF ISNULL(RTrim(@c_Lottable07),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable07 = ''' + @c_Lottable07 + ''''
      IF ISNULL(RTrim(@c_Lottable08),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable08 = ''' + @c_Lottable08 + ''''
      IF ISNULL(RTrim(@c_Lottable09),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable09 = ''' + @c_Lottable09 + ''''
      IF ISNULL(RTrim(@c_Lottable10),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable10 = ''' + @c_Lottable10 + ''''
      IF ISNULL(RTrim(@c_Lottable11),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable11 = ''' + @c_Lottable11 + ''''
      IF ISNULL(RTrim(@c_Lottable12),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable12 = ''' + @c_Lottable12 + ''''

      IF @dt_Lottable04 IS NOT NULL
      BEGIN
         IF CONVERT(NVARCHAR(8) ,@dt_Lottable04 ,112) <> '19000101'
            SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable04 = ''' + CONVERT(NVARCHAR(8) ,@dt_Lottable04 ,112) + ''''
      END

      IF @dt_Lottable05 IS NOT NULL
      BEGIN
         IF CONVERT(NVARCHAR(8) ,@dt_Lottable05 ,112) <> '19000101'
            SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable05 = ''' + CONVERT(NVARCHAR(8) ,@dt_Lottable05 ,112) + ''''
      END

      IF @dt_Lottable13 IS NOT NULL
      BEGIN
         IF CONVERT(NVARCHAR(8) ,@dt_Lottable13 ,112) <> '19000101'
            SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable13 = ''' + CONVERT(NVARCHAR(8) ,@dt_Lottable13 ,112) + ''''
      END

      IF @dt_Lottable14 IS NOT NULL
      BEGIN
         IF CONVERT(NVARCHAR(8) ,@dt_Lottable14 ,112) <> '19000101'
            SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable14 = ''' + CONVERT(NVARCHAR(8) ,@dt_Lottable14 ,112) + ''''
      END

      IF @dt_Lottable15 IS NOT NULL
      BEGIN
         IF CONVERT(NVARCHAR(8) ,@dt_Lottable15 ,112) <> '19000101'
            SELECT @c_Exec_Str = @c_Exec_Str + ' AND LotAttribute.Lottable15 = ''' + CONVERT(NVARCHAR(8) ,@dt_Lottable15 ,112) + ''''
      END

      EXEC (@c_Exec_Str)
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @b_Success = 0
         SELECT @n_Err = 60011
         SELECT @c_Errmsg = 'Fail to insert Top Record into #LotByBatch Table. [nspInventoryHoldWrapper]'
         GOTO EXIT_SP
      END

      SELECT @c_Exec_Str = ''

      --To insert records which are only available in LotAttribute
      SELECT @c_Exec_Str = ' INSERT INTO #LotByBatch ' +
                           ' SELECT la.LOT, '''' InventoryHoldKey ' +
                           ' FROM   LOTATTRIBUTE la (NOLOCK) ' +
                           ' LEFT   JOIN InventoryHold ih (NOLOCK) ON (la.LOT = ih.LOT) ' +
                           ' WHERE  la.StorerKey = ''' + RTrim(@c_StorerKey) + ''' ' +
                           ' AND    la.SKU = ''' + RTrim(@c_SKU) + ''' AND ih.LOT is NULL '

      IF ISNULL(RTrim(@c_Lottable01),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable01 = ''' + @c_Lottable01 + ''''
      IF ISNULL(RTrim(@c_Lottable02),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable02 = ''' + @c_Lottable02 + ''''
      IF ISNULL(RTrim(@c_Lottable03),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable03 = ''' + @c_Lottable03 + ''''
      IF ISNULL(RTrim(@c_Lottable06),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable06 = ''' + @c_Lottable06 + ''''
      IF ISNULL(RTrim(@c_Lottable07),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable07 = ''' + @c_Lottable07 + ''''
      IF ISNULL(RTrim(@c_Lottable08),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable08 = ''' + @c_Lottable08 + ''''
      IF ISNULL(RTrim(@c_Lottable09),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable09 = ''' + @c_Lottable09 + ''''
      IF ISNULL(RTrim(@c_Lottable10),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable10 = ''' + @c_Lottable10 + ''''
      IF ISNULL(RTrim(@c_Lottable11),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable11 = ''' + @c_Lottable11 + ''''
      IF ISNULL(RTrim(@c_Lottable12),'') <> ''  SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable12 = ''' + @c_Lottable12 + ''''

      IF @dt_Lottable04 IS NOT NULL AND CONVERT(NVARCHAR(8) ,@dt_Lottable04 ,112) <> '19000101'
      BEGIN
         SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable04 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable04 ,112) + ''''
      END

      IF @dt_Lottable05 IS NOT NULL AND CONVERT(NVARCHAR(8) ,@dt_Lottable05 ,112) <> '19000101'
      BEGIN
         SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable05 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable05 ,112) + ''''
      END

      IF @dt_Lottable13 IS NOT NULL AND CONVERT(NVARCHAR(8) ,@dt_Lottable13 ,112) <> '19000101'
      BEGIN
         SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable13 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable13 ,112) + ''''
      END

      IF @dt_Lottable14 IS NOT NULL AND CONVERT(NVARCHAR(8) ,@dt_Lottable14 ,112) <> '19000101'
      BEGIN
         SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable14 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable14 ,112) + ''''
      END

      IF @dt_Lottable15 IS NOT NULL AND CONVERT(NVARCHAR(8) ,@dt_Lottable15 ,112) <> '19000101'
      BEGIN
         SELECT @c_Exec_Str = @c_Exec_Str + ' AND la.Lottable15 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable15 ,112) + ''''
      END

      EXEC (@c_Exec_Str)
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @b_Success = 0
         SELECT @n_Err = 60012
         SELECT @c_Errmsg = 'Fail to insert Top Record into #LotByBatch Table. [nspInventoryHoldWrapper]'
         GOTO EXIT_SP
      END

      SELECT @c_Exec_Str = ''

      IF @b_debug=1
      BEGIN
         SELECT * FROM #LotByBatch
      END

      IF NOT EXISTS(
            SELECT COUNT(*)
            FROM   #LotByBatch
            WHERE  LOT <> '' OR LOT IS NOT NULL
            )
      BEGIN
         SELECT @n_continue = 3
         SELECT @b_Success = 0
         SELECT @n_Err = 60013
         SELECT @c_Errmsg = 'No Lot found for the batch. [nspInventoryHoldWrapper]'
      END
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @b_HoldByBatch=1
      BEGIN
         --Modified bt Mohit on 3rd Sep 2004 11:30
         --To check the InventoryHold record-count based on dynamic parameters
         DECLARE @nc_Exec_Str NVARCHAR(MAX)

         SELECT @nc_Exec_Str =
                ' SELECT TOP 1 @cnt = count(StorerKey) FROM InventoryHold (NOLOCK) ' +
                ' WHERE (LOT = '''' OR LOT IS NULL) AND StorerKey = ''' + RTrim(@c_StorerKey) + '''' +
                ' AND   SKU = ''' + RTrim(@c_SKU) + ''''

         IF ISNULL(RTrim(@c_Lottable01),'') <> ''  SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable01 = ''' + @c_Lottable01 + ''''
         IF ISNULL(RTrim(@c_Lottable02),'') <> ''  SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable02 = ''' + @c_Lottable02 + ''''
         IF ISNULL(RTrim(@c_Lottable03),'') <> ''  SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable03 = ''' + @c_Lottable03 + ''''
         IF ISNULL(RTrim(@c_Lottable06),'') <> ''  SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable06 = ''' + @c_Lottable06 + ''''
         IF ISNULL(RTrim(@c_Lottable07),'') <> ''  SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable07 = ''' + @c_Lottable07 + ''''
         IF ISNULL(RTrim(@c_Lottable08),'') <> ''  SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable08 = ''' + @c_Lottable08 + ''''
         IF ISNULL(RTrim(@c_Lottable09),'') <> ''  SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable09 = ''' + @c_Lottable09 + ''''
         IF ISNULL(RTrim(@c_Lottable10),'') <> ''  SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable10 = ''' + @c_Lottable10 + ''''
         IF ISNULL(RTrim(@c_Lottable11),'') <> ''  SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable11 = ''' + @c_Lottable11 + ''''
         IF ISNULL(RTrim(@c_Lottable12),'') <> ''  SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable12 = ''' + @c_Lottable12 + ''''

         IF @dt_Lottable04 IS NOT NULL AND CONVERT(NVARCHAR(8), @dt_Lottable04, 112) <> '19000101'
         BEGIN
            SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable04 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable04, 112) + ''''
         END

         IF @dt_Lottable05 IS NOT NULL AND CONVERT(NVARCHAR(8), @dt_Lottable05, 112) <> '19000101'
         BEGIN
            SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable05 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable05, 112) + ''''
         END

         IF @dt_Lottable13 IS NOT NULL AND CONVERT(NVARCHAR(8) ,@dt_Lottable13 ,112) <> '19000101'
         BEGIN
            SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable13 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable13 ,112) + ''''
         END

         IF @dt_Lottable14 IS NOT NULL AND CONVERT(NVARCHAR(8) ,@dt_Lottable14 ,112) <> '19000101'
         BEGIN
            SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable14 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable14 ,112) + ''''
         END

         IF @dt_Lottable15 IS NOT NULL AND CONVERT(NVARCHAR(8) ,@dt_Lottable15 ,112) <> '19000101'
         BEGIN
            SELECT @nc_Exec_Str = @nc_Exec_Str + ' AND Lottable15 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable15 ,112) + ''''
         END

         DECLARE @cnt AS TINYINT

         EXECUTE sp_executesql @nc_Exec_Str, N'@cnt int OUTPUT', @cnt  OUTPUT

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @b_Success = 0
            SELECT @n_Err = 60014
            SELECT @c_Errmsg = 'Fail to Extract Record From InventoryHold Table. [nspInventoryHoldWrapper]'
            GOTO EXIT_SP
         END

         IF @cnt=0
         BEGIN
            -- Need 1 record with only Lottables value, the lot, ID and Location is '' on top.
            --DECLARE @c_InventoryHoldKey NVARCHAR(10)

            SET ROWCOUNT 0
            EXECUTE nspg_getkey
                'InventoryHoldKey'
                , 10
                , @c_InventoryHoldKey OUTPUT
                , @b_success OUTPUT
                , @n_Err OUTPUT
                , @c_Errmsg OUTPUT

            IF @b_success=0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_Err = 60015
               SELECT @c_Errmsg = @c_Errmsg+' << [nspInventoryHoldWrapper]'
               GOTO EXIT_SP
            END

            IF @n_continue=1 OR @n_continue=2
            BEGIN
               INSERT INTO InventoryHold
                (
                  InventoryHoldKey, Hold, STATUS, StorerKey, SKU,
                  Lottable01, Lottable02, Lottable03, Lottable04,    --Mohit -- IDSV5 - Leo (For V5.1 Feature; remark by Ricky)
                  Lottable05, --Mohit -- IDSV5 - Leo (For V5.1 Feature; remark by Ricky)
                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                  DateOn,    -- SOS89194
                  WhoOn,    -- SOS89194
                  Remark
                ) -- SOS89194
               VALUES
                (
                  @c_InventoryHoldKey, @c_Hold, @c_Status, @c_StorerKey, @c_SKU,
                  @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04,    -- IDSV5 - Leo (For V5.1 Feature; remark by Ricky)
                  @dt_Lottable05,      -- IDSV5 - Leo (For V5.1 Feature; remark by Ricky)
                  @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                  @c_Lottable11, @c_Lottable12, @dt_Lottable13, @dt_Lottable14, @dt_Lottable15,
                  @d_CurrentDatetime, -- SOS89194
                  @c_CurrentUser,      -- SOS89194
                  @c_Remark
                ) -- SOS89194

               IF @@ROWCOUNT=0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @b_Success = 0
                  SELECT @n_Err = 60016
                  SELECT @c_Errmsg = 'Fail to Select Record into InventoryHold Table. [nspInventoryHoldWrapper]'
                  GOTO EXIT_SP
               END

               --MC01 - S
               IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK)
                         WHERE StorerKey = @c_StorerKey
                         AND   ConfigKey = 'INVHSTSLOG'
                         AND   sValue    = '1')
               BEGIN
                  -- (YokeBeen01) - Start 
                  IF @c_hold = '1'
                  BEGIN
                     SELECT @c_Key2 = 'U2H-A'
                  END
                  ELSE
                  BEGIN
                     SELECT @c_Key2 = 'H2U-A'
                  END
                  -- (YokeBeen01) - End 

                  SELECT @c_TransmitLogKey = ''
                  SELECT @b_success = 1
                  EXECUTE nspg_getkey
                         'TransmitlogKey3'
                       , 10
                       , @c_TransmitLogKey OUTPUT
                       , @b_success        OUTPUT
                       , @n_err            OUTPUT
                       , @c_errmsg         OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue=3
                     SELECT @b_Success = 0
                     SELECT @n_Err = 60017
                     SELECT @c_Errmsg = 'Unable to obtain transmitlogkey [nspInventoryHoldWrapper]'
                     GOTO EXIT_SP
                  END
                  ELSE
                  BEGIN
                     INSERT INTO TRANSMITLOG3 (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
                     VALUES (@c_TransmitLogKey, 'INVHSTSLOG', @c_InventoryHoldKey, @c_Key2, @c_StorerKey, '0')

                     IF @@ROWCOUNT=0
                     BEGIN
                        SELECT @n_continue=3
                        SELECT @b_Success = 0
                        SELECT @n_Err = 60018
                        SELECT @c_Errmsg = 'Fail to insert TRANSMITLOG3 Table. [nspInventoryHoldWrapper]'
                        GOTO EXIT_SP
                     END
                  END
               END -- Exists Storerconfig - INVHSTSLOG
               --MC01 - E
            END
         END
         ELSE
         BEGIN
            -- Start - SOS23899, Add by June 04.June.2004
            -- DECLARE @d_CurrentDatetime datetime, @c_CurrentUser NVARCHAR(18)
            -- SELECT @d_CurrentDatetime = GETDATE(), @c_CurrentUser = sUser_sName()
            -- End - SOS23899, Add by June 04.June.2004

            -- Modified by Mohit on 3rd Sep 2004 11:45 AM
            -- Up update the InventoryHold table based on dynamic parameters
            SET ROWCOUNT 0

            --NJOW01 add status update
            SELECT @c_Exec_Str =
                       ' UPDATE INVENTORYHOLD ' +
                       ' SET HOLD = '''+ @c_Hold + ''' ' +
                       ' , DateOn = (CASE '''+RTrim(@c_Hold)+ ''' WHEN ''1'' THEN GETDATE() ELSE DateOn END) ' +
                       ' , WhoOn  = (CASE '''+RTrim(@c_Hold)+ ''' WHEN ''1'' THEN '''+RTrim(@c_CurrentUser) +''' ELSE WhoOn END) ' +
                       ' , DateOff= (CASE '''+RTrim(@c_Hold)+ ''' WHEN ''0'' THEN GETDATE() ELSE DateOff END) ' +
                       ' , WhoOff = (CASE '''+RTrim(@c_Hold)+ ''' WHEN ''0'' THEN '''+RTrim(@c_CurrentUser) +''' ELSE WhoOff END) ' +
                       ' , Status = '''+@c_status + ''' ' +
                       ' , Remark = '''+@c_Remark + ''' ' +   --NJOW02
                       ' FROM  INVENTORYHOLD WHERE (LOT = '''' OR LOT IS NULL) ' +
                       ' AND StorerKey = '''+RTrim(@c_StorerKey)+'''' +
                       ' AND SKU = '''+RTrim(@c_SKU)+''''

            SELECT @c_Exec_Cur = 'DECLARE Cur_InventoryHold CURSOR FAST_FORWARD READ_ONLY FOR '
                               + 'SELECT DISTINCT InventoryHoldKey '
                               + 'FROM   INVENTORYHOLD WITH (NOLOCK) '
                               + 'WHERE (LOT = '''' OR LOT IS NULL) '
                               + 'AND StorerKey = ''' + RTrim(@c_StorerKey) + ''' '
                               + 'AND SKU = ''' + RTrim(@c_SKU) + ''' '

            IF ISNULL(RTrim(@c_Lottable01),'') <> ''
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable01 = ''' + @c_Lottable01 + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable01 = ''' + @c_Lottable01 + '''' --MC01
            END
            ELSE -- (Shong01)
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable01 = '''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable01 = '''''                      --MC01
            END

            IF ISNULL(RTrim(@c_Lottable02),'') <> ''
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable02 = ''' + @c_Lottable02 + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable02 = ''' + @c_Lottable02 + '''' --MC01
            END
            ELSE -- (Shong01)
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable02 = '''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable02 = '''''                      --MC01
            END

            IF ISNULL(RTrim(@c_Lottable03),'') <> ''
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable03 = ''' + @c_Lottable03 + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable03 = ''' + @c_Lottable03 + '''' --MC01
            END
            ELSE -- (Shong01)
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable03 = '''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable03 = '''''                      --MC01
            END

            IF ISNULL(RTrim(@c_Lottable06),'') <> ''
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable06 = ''' + @c_Lottable06 + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable06 = ''' + @c_Lottable06 + ''''
            END
            ELSE
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable06 = '''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable06 = '''''
            END

            IF ISNULL(RTrim(@c_Lottable07),'') <> ''
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable07 = ''' + @c_Lottable07 + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable07 = ''' + @c_Lottable07 + ''''
            END
            ELSE
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable07 = '''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable07 = '''''
            END

            IF ISNULL(RTrim(@c_Lottable08),'') <> ''
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable08 = ''' + @c_Lottable08 + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable08 = ''' + @c_Lottable08 + ''''
            END
            ELSE
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable08 = '''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable08 = '''''
            END

            IF ISNULL(RTrim(@c_Lottable09),'') <> ''
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable09 = ''' + @c_Lottable09 + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable09 = ''' + @c_Lottable09 + ''''
            END
            ELSE
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable09 = '''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable09 = '''''
            END

            IF ISNULL(RTrim(@c_Lottable10),'') <> ''
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable10 = ''' + @c_Lottable10 + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable10 = ''' + @c_Lottable10 + ''''
            END
            ELSE
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable10 = '''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable10 = '''''
            END

            IF ISNULL(RTrim(@c_Lottable11),'') <> ''
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable11 = ''' + @c_Lottable11 + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable11 = ''' + @c_Lottable11 + ''''
            END
            ELSE
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable11 = '''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable11 = '''''
            END

            IF ISNULL(RTrim(@c_Lottable12),'') <> ''
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable12 = ''' + @c_Lottable12 + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable12 = ''' + @c_Lottable12 + ''''
            END
            ELSE
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable12 = '''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable12 = '''''
            END

            IF @dt_Lottable04 IS NOT NULL AND CONVERT(NVARCHAR(8), @dt_Lottable04, 112) <> '19000101'
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable04 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable04, 112) + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable04 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable04, 112) + ''''      --MC01
            END
            ELSE -- (Shong01)
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND (Lottable04 IS NULL OR Lottable04 = ''19000101'')'
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND (Lottable04 IS NULL OR Lottable04 = ''19000101'')'                       --MC01
            END

            IF @dt_Lottable05 IS NOT NULL AND CONVERT(NVARCHAR(8), @dt_Lottable05, 112) <> '19000101'
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable05 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable05, 112) + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable05 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable05, 112) + ''''      --MC01
            END
            ELSE -- (Shong01)
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND (Lottable05 IS NULL OR Lottable05 = ''19000101'')'
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND (Lottable05 IS NULL OR Lottable05 = ''19000101'')'                        --MC01
            END

            IF @dt_Lottable13 IS NOT NULL AND CONVERT(NVARCHAR(8), @dt_Lottable13, 112) <> '19000101'
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable13 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable13, 112) + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable13 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable13, 112) + ''''
            END
            ELSE
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND (Lottable13 IS NULL OR Lottable13 = ''19000101'')'
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND (Lottable13 IS NULL OR Lottable13 = ''19000101'')'
            END

            IF @dt_Lottable14 IS NOT NULL AND CONVERT(NVARCHAR(8), @dt_Lottable14, 112) <> '19000101'
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable14 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable14, 112) + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable14 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable14, 112) + ''''
            END
            ELSE
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND (Lottable14 IS NULL OR Lottable14 = ''19000101'')'
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND (Lottable14 IS NULL OR Lottable14 = ''19000101'')'
            END

            IF @dt_Lottable15 IS NOT NULL AND CONVERT(NVARCHAR(8), @dt_Lottable15, 112) <> '19000101'
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND Lottable15 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable15, 112) + ''''
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND Lottable15 = ''' + CONVERT(NVARCHAR(8), @dt_Lottable15, 112) + ''''
            END
            ELSE
            BEGIN
               SELECT @c_Exec_Str = @c_Exec_Str + ' AND (Lottable15 IS NULL OR Lottable15 = ''19000101'')'
               SELECT @c_Exec_Cur = @c_Exec_Cur + ' AND (Lottable15 IS NULL OR Lottable15 = ''19000101'')'
            END

            EXEC (@c_Exec_Str)

            IF @@ERROR<>0
            BEGIN
               SELECT @n_continue = 3
               SELECT @b_Success = 0
               SELECT @n_Err = 60019
               SELECT @c_Errmsg = 'Fail to UPDATE INVENTORYHOLD Table. [nspInventoryHoldWrapper]'
               GOTO EXIT_SP
            END

            --MC01 - S
            IF @c_hold = '1'
            BEGIN
               SELECT @c_Key2 = 'U2H'
            END
            ELSE
            BEGIN
               SELECT @c_Key2 = 'H2U'
            END

            IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK)
                      WHERE StorerKey = @c_StorerKey
                      AND   ConfigKey = 'INVHSTSLOG'
                      AND   sValue    = '1')
            BEGIN
               EXEC(@c_Exec_Cur)

               OPEN Cur_InventoryHold
               FETCH NEXT FROM Cur_InventoryHold INTO @c_InventoryHoldKey

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SELECT @c_TransmitLogKey = ''
                  SELECT @b_success = 1
                  EXECUTE nspg_getkey
                         'TransmitlogKey3'
                       , 10
                       , @c_TransmitLogKey OUTPUT
                       , @b_success        OUTPUT
                       , @n_err            OUTPUT
                       , @c_errmsg         OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue=3
                     SELECT @b_Success = 0
                     SELECT @n_Err = 60019
                     SELECT @c_Errmsg = 'Unable to obtain transmitlogkey [nspInventoryHoldWrapper]'
                     GOTO EXIT_SP
                  END
                  ELSE
                  BEGIN
                     INSERT INTO TRANSMITLOG3 (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
                     VALUES (@c_TransmitLogKey, 'INVHSTSLOG', @c_InventoryHoldKey, @c_Key2, @c_StorerKey, '0')

                     IF @@ROWCOUNT=0
                     BEGIN
                        SELECT @n_continue=3
                        SELECT @b_Success = 0
                        SELECT @n_Err = 60020
                        SELECT @c_Errmsg = 'Fail to insert TRANSMITLOG3 Table. [nspInventoryHoldWrapper]'
                        GOTO EXIT_SP
                     END
                  END

                  FETCH NEXT FROM Cur_InventoryHold INTO @c_InventoryHoldKey
               END -- WHILE @@FETCH_STATUS <> -1
               CLOSE Cur_InventoryHold
               DEALLOCATE Cur_InventoryHold
            END -- Exists Storerconfig - INVHSTSLOG
            --MC01 - E
         END

         IF @n_continue=1 OR @n_continue=2
         BEGIN
            DECLARE @c_CurrentLot NVARCHAR(10)

            WHILE EXISTS(SELECT * FROM #LotByBatch)
            BEGIN
               SET @c_Hold_Chg = ''            --(MC01)

               SELECT TOP 1 @c_CurrentLot = lot
               FROM   #LotByBatch
               ORDER  BY LOT

               IF @b_debug=1
               BEGIN
                  SELECT '@c_CurrentLot: '+@c_CurrentLot
               END

               IF @c_Hold<>'1'
               BEGIN
                  SELECT @c_Status = STATUS
                  FROM   INVENTORYHOLD(NOLOCK)
                  WHERE  LOT = @c_CurrentLot
               END

               -- NJOW01 -Start
               SELECT @c_CurrHold = ''

               SELECT @n_HoldCnt = COUNT(1)
               FROM   INVENTORYHOLD(NOLOCK)
               WHERE  lot = @c_CurrentLot
               AND loc = ''
               AND id = ''
               AND hold = '1'

               SELECT @n_ReleaseCnt = COUNT(1)
               FROM   INVENTORYHOLD(NOLOCK)
               WHERE  lot  = @c_CurrentLot
               AND    loc  = ''
               AND    id   = ''
               AND    hold = '0'

               IF @n_HoldCnt=1 AND @c_Hold='1'
               BEGIN
                  UPDATE INVENTORYHOLD WITH (ROWLOCK)
                  SET    STATUS = @c_status
                  WHERE  lot  = @c_CurrentLot
                  AND    loc  = ''
                  AND    id   = ''
                  AND    hold = '1'

                  SELECT @c_CurrHold = '1'
               END

               IF @n_HoldCnt=0 AND @n_ReleaseCnt=1 AND @c_Hold='1'
               BEGIN
                  UPDATE INVENTORYHOLD WITH (ROWLOCK)
                  SET    STATUS = @c_status
                  WHERE  lot  = @c_CurrentLot
                  AND    loc  = ''
                  AND    id   = ''
                  AND    hold = '0'

                  SELECT @c_CurrHold = '0'
               END

               IF @n_HoldCnt=1 AND @c_Hold='0'
               BEGIN
                  UPDATE INVENTORYHOLD WITH (ROWLOCK)
                  SET    STATUS = @c_status
                  WHERE  lot  = @c_CurrentLot
                  AND    loc  = ''
                  AND    id   = ''
                  AND    hold = '1'

                  SELECT @c_CurrHold = '1'
               END
               --NJOW -End

               --NJOW02-start
               IF @n_ReleaseCnt=1 AND @c_Hold='0'
                  SELECT @c_CurrHold = '0'

               UPDATE INVENTORYHOLD WITH (ROWLOCK)
               SET   REMARK = @c_Remark
               WHERE lot = @c_CurrentLot
               AND   loc = ''
               AND   id  = ''
               --NJOW02-end

               -- If nothing to release, then set current hold = hold
               IF @n_HoldCnt=0 AND @c_Hold='0'
                  SET @c_CurrHold = '0'

               IF @c_Hold <> '1'
               BEGIN
                  -- Check if any of the lottable still on hold
                  -- Check if
                  IF EXISTS(SELECT 1
                            FROM LOTATTRIBUTE LA WITH (NOLOCK)
                            JOIN INVENTORYHOLD IH WITH (NOLOCK) ON IH.StorerKey = LA.StorerKey
                            AND  IH.SKU = LA.Sku
                            AND  IH.Hold = '1'
                            AND  IH.Lottable01 = CASE WHEN IH.Lottable01 <> '' THEN LA.Lottable01 ELSE '' END     --(TK01)
                            AND  IH.Lottable02 = CASE WHEN IH.Lottable02 <> '' THEN LA.Lottable02 ELSE '' END     --(TK01)
                            AND  IH.Lottable03 = CASE WHEN IH.Lottable03 <> '' THEN LA.Lottable03 ELSE '' END     --(TK01)
                            AND  IH.Lottable06 = CASE WHEN IH.Lottable06 <> '' THEN LA.Lottable06 ELSE '' END     --(TK01)
                            AND  IH.Lottable07 = CASE WHEN IH.Lottable07 <> '' THEN LA.Lottable07 ELSE '' END     --(TK01)
                            AND  IH.Lottable08 = CASE WHEN IH.Lottable08 <> '' THEN LA.Lottable08 ELSE '' END     --(TK01)
                            AND  IH.Lottable09 = CASE WHEN IH.Lottable09 <> '' THEN LA.Lottable09 ELSE '' END     --(TK01)
                            AND  IH.Lottable10 = CASE WHEN IH.Lottable10 <> '' THEN LA.Lottable10 ELSE '' END     --(TK01)
                            AND  IH.Lottable11 = CASE WHEN IH.Lottable11 <> '' THEN LA.Lottable11 ELSE '' END     --(TK01)
                            AND  IH.Lottable12 = CASE WHEN IH.Lottable12 <> '' THEN LA.Lottable12 ELSE '' END     --(TK01)
                            AND  IH.Lottable04 = CASE WHEN ISNULL(IH.Lottable04,'19000101') <> '19000101' THEN LA.Lottable04 ELSE '' END  --WL01
                            AND  IH.Lottable05 = CASE WHEN ISNULL(IH.Lottable05,'19000101') <> '19000101' THEN LA.Lottable05 ELSE '' END  --WL01
                            AND  IH.Lottable13 = CASE WHEN ISNULL(IH.Lottable13,'19000101') <> '19000101' THEN LA.Lottable13 ELSE '' END  --WL01
                            AND  IH.Lottable14 = CASE WHEN ISNULL(IH.Lottable14,'19000101') <> '19000101' THEN LA.Lottable14 ELSE '' END  --WL01
                            AND  IH.Lottable15 = CASE WHEN ISNULL(IH.Lottable15,'19000101') <> '19000101' THEN LA.Lottable15 ELSE '' END  --WL01

                            -- SOS# 355593
                            AND (IH.Lot = '' OR IH.Lot IS NULL)
                            AND (IH.Loc= '' OR IH.Loc IS NULL)
                            AND (IH.Id= '' OR IH.Id IS NULL)
                            WHERE LA.StorerKey = @c_StorerKey
                            AND   LA.Sku       = @c_SKU
                            AND   LA.Lot       = @c_CurrentLot)
                  BEGIN
                     -- Do not release when other Lottable still on-hold
                     SET @c_Hold_Chg = '1'
                  END
                  ELSE
                  BEGIN
                     SET @c_Hold_Chg = @c_Hold --MC01
                  END
               END
               ELSE
               BEGIN
                  SET @c_Hold_Chg = @c_Hold --MC01
               END
               -- (Shong01) End

               IF @b_debug = 1
               BEGIN
                  SELECT '@c_CurrHold : ' + @c_CurrHold
                  SELECT '@c_Hold : '     + @c_Hold
                  SELECT '@c_Hold_Chg : ' + @c_Hold_Chg
               END

               --IF @c_CurrHold<>@c_Hold --NJOW01
               IF @c_CurrHold <> @c_Hold_Chg  --MC01
               BEGIN
                  EXECUTE nspInventoryHold
                          @c_CurrentLot
                        , ''
                        , ''
                        , @c_Status
                        , @c_Hold_Chg           --(TK01) Corrected @c_Hold to @c_Hold_Chg
                        , @b_Success OUTPUT
                        , @n_Err OUTPUT
                        , @c_Errmsg OUTPUT
                        , @c_Remark -- SOS89194
               END
               ELSE
                  SELECT @b_success = 1 --NJOW01

               IF @b_Success=0
               BEGIN
                  SELECT @n_continue = 3
                  DELETE FROM #LotByBatch
                  SELECT @n_Err = 60021
                  SELECT @c_Errmsg = 'Execute nspInventoryHold Failed. [nspInventoryHoldWrapper]'
                  GOTO EXIT_SP
               END
               ELSE
               BEGIN
                  DELETE FROM   #LotByBatch
                  WHERE  lot = @c_CurrentLot
               END
            END
         END
      END   -- IF @b_HoldByBatch = 1
      ELSE  -- @b_HoldByBatch = 0
      BEGIN
         IF ISNULL(RTRIM(@c_lot) ,'') <> ''
         BEGIN
            SELECT @c_StorerKey = StorerKey  
            FROM   LOT WITH (NOLOCK)
            WHERE  LOT = @c_lot
         END  
         ELSE IF ISNULL(RTRIM(@c_loc) ,'') <> ''
         BEGIN
            SELECT TOP 1 @c_StorerKey = StorerKey  
            FROM SKUxLOC WITH (NOLOCK)
            WHERE LOC = @c_LOC 
            AND   Qty > 0 
         END
         ELSE IF ISNULL(RTRIM(@c_id ) ,'') <> ''
         BEGIN
            SELECT TOP 1 @c_StorerKey = StorerKey  
            FROM  LOTxLOCxID WITH (NOLOCK)
            WHERE ID = @c_ID 
            AND Qty > 0  
         END
         
         -- SWT01
         SET @c_ChannelInventoryMgmt = '0'
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspGetRight2 --(Wan01) 
             @c_Facility  = '',
             @c_StorerKey = @c_StorerKey,        -- Storer
             @c_sku       = '',                  -- Sku
             @c_ConfigKey = 'ChannelInventoryMgmt',  -- ConfigKey
             @b_Success   = @b_success    OUTPUT,
             @c_authority = @c_ChannelInventoryMgmt  OUTPUT,
             @n_err       = @n_Err        OUTPUT,
             @c_errmsg    = @c_ErrMsg     OUTPUT,                            
             @c_Option1   = @c_Option1    OUTPUT,  --NJOW03
             @c_Option2   = @c_Option2    OUTPUT,
             @c_Option3   = @c_Option3    OUTPUT,
             @c_Option4   = @c_Option4    OUTPUT,
             @c_Option5   = @c_Option5    OUTPUT

            IF @b_success <> 1
            BEGIN
               Select @n_continue = 3, @c_ErrMsg = 'nspInventoryHoldWrapper:' + ISNULL(RTRIM(@c_ErrMsg),'')
            END
         END               
         IF @c_ChannelInventoryMgmt = '1'
            AND dbo.fnc_GetParamValueFromString('@c_AllowInvHoldInChannelMgmt', @c_Option5, 'N') <> 'Y'  --NJOW03         
         BEGIN
            SELECT @n_continue = 3
            SELECT @b_Success = 0
            SELECT @n_Err = 60022
            SELECT @c_Errmsg = 'Inventory Hold Not allow for Channel Management Customer. [nspInventoryHoldWrapper]'
            GOTO EXIT_SP 
         END
                        
         --NJOW01-Start
         SELECT @c_CurrHold = ''

         SELECT @n_HoldCnt = COUNT(*)
         FROM   INVENTORYHOLD(NOLOCK)
         WHERE  lot  = ISNULL(@c_lot ,'')
         AND    loc  = ISNULL(@c_loc ,'')
         AND    id   = ISNULL(@c_id ,'')
         AND    hold = '1'

         SELECT @n_ReleaseCnt = COUNT(*)
         FROM   INVENTORYHOLD(NOLOCK)
         WHERE  lot  = ISNULL(@c_lot ,'')
         AND    loc  = ISNULL(@c_loc ,'')
         AND    id   = ISNULL(@c_id ,'')
         AND    hold = '0'

         IF @n_HoldCnt=1 AND @c_Hold='1'
         BEGIN
            UPDATE INVENTORYHOLD WITH (ROWLOCK)
            SET    STATUS = @c_status
            WHERE  lot  = ISNULL(@c_lot ,'')
            AND    loc  = ISNULL(@c_loc ,'')
            AND    id   = ISNULL(@c_id ,'')
            AND    hold = '1'

            SELECT @c_CurrHold = '1'
         END

         IF @n_HoldCnt=0
            AND @n_ReleaseCnt=1
            AND @c_Hold='1'
         BEGIN
            UPDATE INVENTORYHOLD WITH (ROWLOCK)
            SET    STATUS = @c_status
            WHERE  lot  = ISNULL(@c_lot ,'')
            AND    loc  = ISNULL(@c_loc ,'')
            AND    id   = ISNULL(@c_id ,'')
            AND    hold = '0'

            SELECT @c_CurrHold = '0'
         END

         IF @n_HoldCnt=1
            AND @c_Hold='0'
         BEGIN
            UPDATE INVENTORYHOLD WITH (ROWLOCK)
            SET    STATUS = @c_status
            WHERE  lot  = ISNULL(@c_lot ,'')
            AND    loc  = ISNULL(@c_loc ,'')
            AND    id   = ISNULL(@c_id ,'')
            AND    hold = '1'

            SELECT @c_CurrHold = '1'
         END
         --NJOW01-End

         --NJOW02-start
         IF @n_ReleaseCnt=1 AND @c_Hold='0'
            SELECT @c_CurrHold = '0'

         UPDATE INVENTORYHOLD WITH (ROWLOCK)
         SET    REMARK = @c_remark
         WHERE  lot = ISNULL(@c_lot ,'')
         AND    loc = ISNULL(@c_loc ,'')
         AND    id  = ISNULL(@c_id ,'')
         --NJOW02-end

         IF (@c_CurrHold <> @c_Hold) --NJOW01
         BEGIN
            EXECUTE nspInventoryHold
                     @c_lot
                   , @c_Loc
                   , @c_ID
                   , @c_Status
                   , @c_Hold
                   , @b_Success OUTPUT
                   , @n_Err OUTPUT
                   , @c_Errmsg OUTPUT
                   , @c_Remark -- SOS89194

            IF @b_Success=0
            BEGIN
               SELECT @n_continue = 3
               --DELETE FROM #LotByBatch        (Wan02)
               SELECT @n_Err = 60008
               SELECT @c_Errmsg = 'Execute nspInventoryHold Failed. [nspInventoryHoldWrapper]'
               GOTO EXIT_SP
            END
         END
      END -- ELSE [IF @b_HoldByBatch = 0]
   END -- IF @n_continue = 1 OR @n_continue = 2

EXIT_SP:
   IF @n_continue=3
   BEGIN
      IF @@TRANCOUNT = 1 AND (@@TRANCOUNT>@n_starttcnt)        --(Wan02) 
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT>@n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT>@n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END --MAIN

GO