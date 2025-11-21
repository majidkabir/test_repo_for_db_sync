SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Stored Procedure: ispASNFZ11                                            */
/* Creation Date: 18-Sep-2017                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-2866 - CN PVH ASN finalize syncronize sku with other storer*/
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 2019-01-10   CSCHONG 1.0   WMS-7547 (CS01)                              */
/* 2020-11-26   CSCHONG 1.1   WMS-15569 revised report logic (CS02)        */
/* 2021-03-02   CSCHONG 1.2   WMS-15569 revised field logic (CS03)         */
/* 2022-06-13   CSCHONG 1.3   WMS-19798 revised field logic (CS04)         */
/* 2022-08-01   CSCHONG 1.4   WMS-19798 revised field logic (CS04a)        */
/* 2022-08-09   CSCHONG 1.5   WMS-19798 revised field logic (CS04b)        */
/***************************************************************************/
CREATE   PROC [dbo].[ispASNFZ11]
(     @c_Receiptkey  NVARCHAR(10)
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
  ,   @c_ReceiptLineNumber NVARCHAR(5)=''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue       INT,
           @n_StartTranCount INT,
           @c_Storerkey      NVARCHAR(15),
           @c_Facility       NVARCHAR(5),
           @c_authority      NVARCHAR(30),
           @c_option1        NVARCHAR(50),
           @c_option2        NVARCHAR(50),
           @c_option3        NVARCHAR(50),
           @c_option4        NVARCHAR(50),
           @c_option5        NVARCHAR(4000),
           @c_Sku            NVARCHAR(20)

   --CS01 Start
   DECLARE
           @n_StartTCnt             INT
         , @c_DocType               NVARCHAR(10)
         , @c_RecType               NVARCHAR(10)

         , @c_Packkey               NVARCHAR(10)
         , @c_UOM                   NVARCHAR(10)
         , @c_UDF10                 NVARCHAR(30)
         , @c_UDF02                 NVARCHAR(30)

         , @c_AdjustmentType        NVARCHAR(10)
         , @c_AdjustmentType1       NVARCHAR(10)
         , @c_AdjustmentType2       NVARCHAR(10)
         , @c_AdjustmentKeys        NVARCHAR(10)
         , @c_AdjustmentKey         NVARCHAR(10)

         , @c_AdjustmentLineNumber  NVARCHAR(5)
         , @c_ReasonCode            NVARCHAR(10)
         , @c_ShortReasonCode       NVARCHAR(10)
         , @c_OverReasonCode        NVARCHAR(10)
         , @c_Loc                   NVARCHAR(10)
         , @c_Lottable02            NVARCHAR(18)
         , @dt_Lottable05           DATETIME
         , @n_QtyExpected           INT
         , @n_QtyReceived           INT
         , @n_QtyVariance           INT

         , @n_KeyNo                 INT
         , @n_KeyNo1                INT
         , @n_KeyNo2                INT
         , @n_KeyLineNo             INT
         , @n_Cnt                   INT
         , @n_Batch                 INT
         , @c_Clkudf03              NVARCHAR(60)         --CS04     
         , @c_ExtReckey             NVARCHAR(50)         --CS04  

       --CS02 START
  DECLARE  @c_lot                   NVARCHAR(10)
         , @c_Lot01                 NVARCHAR(18)
         , @c_Lot02                 NVARCHAR(18)
         , @c_Lot03                 NVARCHAR(18)
         , @c_Lot06                 NVARCHAR(30)
         , @d_Lot04                 DATETIME
         , @d_Lot05                 DATETIME
         , @c_Lot07                 NVARCHAR(30)
         , @c_Lot08                 NVARCHAR(30)
         , @c_Lot09                 NVARCHAR(30)
         , @c_Lot10                 NVARCHAR(30)
         , @c_Lot11                 NVARCHAR(30)
         , @c_Lot12                 NVARCHAR(30)
         , @d_Lot13                 DATETIME
         , @d_Lot14                 DATETIME
         , @d_Lot15                 DATETIME
         , @c_toid                  NVARCHAR(50)
         , @c_Lottable07            NVARCHAR(30)
         , @c_Lottable08            NVARCHAR(30)
         , @c_RecGrp                NVARCHAR(20)
         , @c_ASNReason             NVARCHAR(10)
         , @c_RDLineNo              NVARCHAR(10)
         , @c_toLoc                 NVARCHAR(10)
         , @c_RDUDF01               NVARCHAR(30)
         , @c_RDUDF03               NVARCHAR(30)   --CS04b
         , @c_Lottable06            NVARCHAR(30)   --CS04b

      --CS02 END

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   CREATE TABLE #TMP_ADJ
         (  KeyNo          INT            NOT NULL
         ,  AdjustmentKey  NVARCHAR(10)   NULL
         ,  AdjustmentType NVARCHAR(10)   NULL
         ,  Storerkey      NVARCHAR(15)   NULL
         ,  Facility       NVARCHAR(5)    NULL
         ,  UserDefine01   NVARCHAR(30)   NULL
         ,  ASNReason      NVARCHAR(20)   NULL            --CS02
         ,  UserDefine02   NVARCHAR(30)   NULL            --CS04
         )

   CREATE TABLE #TMP_ADJDET
         (  KeyNo                INT            NOT NULL
         ,  AdjustmentKey        NVARCHAR(10)   NULL
         ,  AdjustmentLineNumber NVARCHAR(5)    NULL
         ,  Storerkey            NVARCHAR(15)   NULL
         ,  Sku                  NVARCHAR(20)   NULL
         ,  Packkey              NVARCHAR(10)   NULL
         ,  UOM                  NVARCHAR(10)   NULL
         ,  Lot                  NVARCHAR(10)   NULL
         ,  Loc                  NVARCHAR(10)   NULL
         ,  ID                   NVARCHAR(18)   NULL
         ,  Qty                  INT            NULL
         ,  ReasonCode           NVARCHAR(10)   NULL
         ,  Lottable05           DATETIME       NULL
         ,  Channel              NVARCHAR(20)   NULL     --CS01
         ,  Lottable01           NVARCHAR(18)   NULL
         ,  Lottable02           NVARCHAR(18)   NULL
         ,  Lottable03           NVARCHAR(18)   NULL
         ,  Lottable04           DATETIME       NULL
        -- ,  Lottable05           DATETIME       NULL
         ,  Lottable06           NVARCHAR(30)   NULL
         ,  Lottable07           NVARCHAR(30)   NULL
         ,  Lottable08           NVARCHAR(30)   NULL
         ,  Lottable09           NVARCHAR(30)   NULL
         ,  Lottable10           NVARCHAR(30)   NULL
         ,  Lottable11           NVARCHAR(30)   NULL
         ,  Lottable12           NVARCHAR(30)   NULL
         ,  Lottable13           DATETIME       NULL
         ,  Lottable14           DATETIME       NULL
         ,  Lottable15           DATETIME       NULL
         ,  QtyExpected          INT            NULL
         ,  QtyReceived          INT            NULL
         ,  UCCNO                NVARCHAR(30)   NULL         --CS02
         ,  Userdefine03         NVARCHAR(30)   NULL         --CS04b
         )
      --CS01 End
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT

   IF @n_continue IN (1,2)
   BEGIN
        SELECT @c_Storerkey = R.Storerkey,
               @c_Facility = R.Facility
        FROM RECEIPT R (NOLOCK)
        WHERE R.Receiptkey = @c_Receiptkey

        Execute nspGetRight
              @c_facility,
              @c_StorerKey,
              '', -- @c_SKU,
              'PostFinalizeReceiptSP ', -- Configkey
              @b_success    OUTPUT,
              @c_authority  OUTPUT,
              @n_err        OUTPUT,
              @c_errmsg     OUTPUT,
              @c_option1    OUTPUT,  --other storer
              @c_option2    OUTPUT,  --other strategykey
              @c_option3    OUTPUT,
              @c_option4    OUTPUT,
              @c_option5    OUTPUT

      IF NOT EXISTS(SELECT 1 FROM STORER (NOLOCK) WHERE Storerkey = @c_Option1)
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63500
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid Storerkey of option1 (ispASNFZ11)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END

      IF NOT EXISTS(SELECT 1 FROM STRATEGY (NOLOCK) WHERE Strategykey = @c_Option2)
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63510
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid strategykey of option2 (ispASNFZ11)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END
   END

   IF @n_continue IN (1,2)
   BEGIN
      DECLARE CUR_RECEIPTDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT RD.Sku
         FROM RECEIPTDETAIL RD (NOLOCK)
         LEFT JOIN SKU (NOLOCK) ON RD.Sku = SKU.Sku AND SKU.Storerkey = @c_Option1
         WHERE RD.Receiptkey = @c_Receiptkey
         AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE RD.ReceiptLineNumber END
         AND SKU.Sku IS NULL

      OPEN CUR_RECEIPTDETAIL
      FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @c_Sku

      WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)
      BEGIN
         INSERT INTO SKU
         (
            StorerKey,
            Sku,
            DESCR,
            SUSR1,
            SUSR2,
            SUSR3,
            SUSR4,
            SUSR5,
            MANUFACTURERSKU,
            RETAILSKU,
            ALTSKU,
            PACKKey,
            STDGROSSWGT,
            STDNETWGT,
            STDCUBE,
            TARE,
            CLASS,
            [ACTIVE],
            SKUGROUP,
            Tariffkey,
            BUSR1,
            BUSR2,
            BUSR3,
            BUSR4,
            BUSR5,
            LOTTABLE01LABEL,
            LOTTABLE02LABEL,
            LOTTABLE03LABEL,
            LOTTABLE04LABEL,
            LOTTABLE05LABEL,
            NOTES1,
            NOTES2,
            PickCode,
            StrategyKey,
            CartonGroup,
            PutCode,
            PutawayLoc,
            PutawayZone,
            InnerPack,
            [Cube],
            GrossWgt,
            NetWgt,
            ABC,
            CycleCountFrequency,
            LastCycleCount,
            ReorderPoint,
            ReorderQty,
            StdOrderCost,
            CarryCost,
            Price,
            Cost,
            ReceiptHoldCode,
            ReceiptInspectionLoc,
            OnReceiptCopyPackkey,
            IOFlag,
            TareWeight,
            LotxIdDetailOtherlabel1,
            LotxIdDetailOtherlabel2,
            LotxIdDetailOtherlabel3,
            AvgCaseWeight,
            TolerancePct,
            SkuStatus,
            Length,
            Width,
            Height,
            [weight],
            itemclass,
            ShelfLife,
            Facility,
            BUSR6,
            BUSR7,
            BUSR8,
            BUSR9,
            BUSR10,
            ReturnLoc,
            ReceiptLoc,
            archiveqty,
            XDockReceiptLoc,
            PrePackIndicator,
            PackQtyIndicator,
            StackFactor,
            IVAS,
            OVAS,
            Style,
            Color,
            [Size],
            Measurement,
            HazardousFlag,
            TemperatureFlag,
            ProductModel,
            CtnPickQty,
            CountryOfOrigin,
            IB_UOM,
            IB_RPT_UOM,
            OB_UOM,
            OB_RPT_UOM,
            ABCPL,
            ABCCS,
            ABCEA,
            DisableABCCalc,
            ABCPeriod,
            ABCStorerkey,
            ABCSku,
            --ABCExcludeSUSRNo,
            --ABCExcludeSUSRValue,
            OldStorerkey,
            OldSku,
            LOTTABLE06LABEL,
            LOTTABLE07LABEL,
            LOTTABLE08LABEL,
            LOTTABLE09LABEL,
            LOTTABLE10LABEL,
            LOTTABLE11LABEL,
            LOTTABLE12LABEL,
            LOTTABLE13LABEL,
            LOTTABLE14LABEL,
            LOTTABLE15LABEL,
            LottableCode,
            ImageFolder,
            OTM_SKUGroup,
            Pressure,
            SerialNoCapture
)
         SELECT
            @c_Option1,
            Sku,
            DESCR,
            SUSR1,
            SUSR2,
            SUSR3,
            SUSR4,
            SUSR5,
            MANUFACTURERSKU,
            RETAILSKU,
            ALTSKU,
            PACKKey,
            STDGROSSWGT,
            STDNETWGT,
            STDCUBE,
            TARE,
            CLASS,
            [ACTIVE],
            SKUGROUP,
            Tariffkey,
            BUSR1,
            BUSR2,
            BUSR3,
            BUSR4,
            BUSR5,
            LOTTABLE01LABEL,
            LOTTABLE02LABEL,
            LOTTABLE03LABEL,
            LOTTABLE04LABEL,
            LOTTABLE05LABEL,
            NOTES1,
            NOTES2,
            PickCode,
            @c_Option2,
            CartonGroup,
            PutCode,
            PutawayLoc,
            PutawayZone,
            InnerPack,
            [Cube],
            GrossWgt,
            NetWgt,
            ABC,
            CycleCountFrequency,
            LastCycleCount,
            ReorderPoint,
            ReorderQty,
            StdOrderCost,
            CarryCost,
            Price,
            Cost,
            ReceiptHoldCode,
            ReceiptInspectionLoc,
            OnReceiptCopyPackkey,
            IOFlag,
            TareWeight,
            LotxIdDetailOtherlabel1,
            LotxIdDetailOtherlabel2,
            LotxIdDetailOtherlabel3,
            AvgCaseWeight,
            TolerancePct,
            SkuStatus,
            Length,
            Width,
            Height,
            [weight],
            itemclass,
            ShelfLife,
            Facility,
            BUSR6,
            BUSR7,
            BUSR8,
            BUSR9,
            BUSR10,
            ReturnLoc,
            ReceiptLoc,
            archiveqty,
            XDockReceiptLoc,
            PrePackIndicator,
            PackQtyIndicator,
            StackFactor,
            IVAS,
            OVAS,
            Style,
            Color,
            [Size],
            Measurement,
            HazardousFlag,
            TemperatureFlag,
            ProductModel,
            CtnPickQty,
            CountryOfOrigin,
            IB_UOM,
            IB_RPT_UOM,
            OB_UOM,
            OB_RPT_UOM,
            ABCPL,
            ABCCS,
            ABCEA,
            DisableABCCalc,
            ABCPeriod,
            ABCStorerkey,
            ABCSku,
            --ABCExcludeSUSRNo,
            --ABCExcludeSUSRValue,
            OldStorerkey,
            OldSku,
            LOTTABLE06LABEL,
            LOTTABLE07LABEL,
            LOTTABLE08LABEL,
            LOTTABLE09LABEL,
            LOTTABLE10LABEL,
            LOTTABLE11LABEL,
            LOTTABLE12LABEL,
            LOTTABLE13LABEL,
            LOTTABLE14LABEL,
            LOTTABLE15LABEL,
            LottableCode,
            ImageFolder,
            OTM_SKUGroup,
            Pressure,
            SerialNoCapture
         FROM SKU (NOLOCK)
         WHERE Storerkey = @c_Storerkey
         AND Sku = @c_Sku

         SELECT @n_err = @@ERROR
         IF  @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63510
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert SKU Table Failed! (ispASNFZ11)' + ' ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END

         FETCH NEXT FROM CUR_RECEIPTDETAIL INTO @c_Sku
      END
      CLOSE CUR_RECEIPTDETAIL
      DEALLOCATE CUR_RECEIPTDETAIL
   END
   --STEP 1
   --CS01 Start
   SET @c_Facility = ''
   SET @c_Storerkey= ''
   SET @c_DocType  = ''
   SET @c_RecType  = ''
   SET @c_UDF10 = ''
   SET @c_UDF02 = ''
   SET @c_RecGrp = ''     --CS02
  --print 'start'
   SELECT @c_Facility = RECEIPT.Facility
         ,@c_Storerkey= RECEIPT.Storerkey
         ,@c_DocType  = RECEIPT.DocType
         ,@c_RecType  = RECEIPT.RecType
         ,@c_UDF10    = RECEIPT.userdefine10
         ,@c_UDF02    = RECEIPT.userdefine02
         ,@c_ASNReason   = RECEIPT.ASNReason            --CS02
         ,@c_RecGrp      = RECEIPT.ReceiptGroup        --CS04
         ,@c_ExtReckey   = RECEIPT.ExternReceiptKey     --CS04
   FROM   RECEIPT WITH (NOLOCK)
   WHERE  RECEIPT.ReceiptKey = @c_ReceiptKey
   AND    RECEIPT.DocType = 'R'
   AND    (RECEIPT.userdefine02='TU' OR RECEIPT.receiptgroup = 'R')
   --AND    RECEIPT.RecType = 'RTN'

   IF @c_DocType <> 'R'
   BEGIN
      GOTO QUIT_SP
   END

   --IF @c_RecType = 'NIF'
   --BEGIN
   --   GOTO QUIT_SP
   --END

   --IF @c_UDF02 <> 'TU'
   --BEGIN
   --   GOTO QUIT_SP
   --END
   --CS04a S
   SET @c_Loc = ''
   --SELECT @c_Loc = FACILITY.UserDefine04
   --FROM FACILITY WITH (NOLOCK)
   --WHERE Facility = @c_Facility

       SELECT TOP 1 @c_Loc =  UDF03
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'PVHSHLOC'
      AND   Storerkey = @c_Storerkey
     AND code2  = @c_Facility
     and code = @c_UDF10

--CS04a E

   IF EXISTS ( SELECT 1
               FROM   RECEIPTDETAIL WITH (NOLOCK)
               WHERE  RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey
               AND    RECEIPTDETAIL.QtyExpected <> RECEIPTDETAIL.QtyReceived
             )
   BEGIN
      SET @c_AdjustmentType = ''
      SELECT TOP 1 @c_AdjustmentType1 = SUBSTRING(Code,3,28)
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'NONADJITF'
      AND   Storerkey = @c_Storerkey
      AND short='1'                            --CS04

      --CS04 START

     SELECT TOP 1 @c_Clkudf03 = UDF03
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'PVHASN'
      AND   Storerkey = @c_Storerkey
     AND short  = @c_DocType
     and Codelkup.long = @c_RecGrp

      --CS04 END

      SET @c_Lottable02 = ''
      SET @c_AdjustmentType2 = @c_Clkudf03 --'001'        --CS04

     SET @c_ReasonCode = ''
      SELECT TOP 1 @c_ReasonCode = CASE WHEN @c_ASNReason ='DC' THEN 'PO' ELSE long END  --CS04a
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'ASN2ADJ'
      AND   Storerkey = @c_Storerkey
     AND short  = @c_DocType
     and Codelkup.UDF01 = @c_UDF10

   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

    BEGIN TRAN

   SET @n_KeyNo = -1
   DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT KeyLineNo = ROW_NUMBER() OVER (PARTITION BY RECEIPTDETAIL.ReceiptKey
                                        , CASE WHEN RECEIPTDETAIL.QtyExpected > RECEIPTDETAIL.QtyReceived THEN 0
                                          WHEN RECEIPTDETAIL.QtyExpected < RECEIPTDETAIL.QtyReceived THEN 5
                                          ELSE 9 END
                                          ORDER BY
                                          CASE WHEN RECEIPTDETAIL.QtyExpected > RECEIPTDETAIL.QtyReceived THEN 0
                                               WHEN RECEIPTDETAIL.QtyExpected < RECEIPTDETAIL.QtyReceived THEN 5
                                               ELSE 9 END)
         ,RECEIPTDETAIL.Sku
         ,RECEIPTDETAIL.Packkey
         ,RECEIPTDETAIL.UOM
         ,RECEIPTDETAIL.QtyExpected
         ,RECEIPTDETAIL.QtyReceived
         ,RECEIPTDETAIL.lottable07, RECEIPTDETAIL.lottable08        -- CS02
         ,RECEIPTDETAIL.userdefine03,RECEIPTDETAIL.lottable06       --CS04b
   FROM   RECEIPTDETAIL WITH (NOLOCK)
   WHERE  RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey
   ORDER BY CASE WHEN RECEIPTDETAIL.QtyExpected > RECEIPTDETAIL.QtyReceived THEN 0
                 WHEN RECEIPTDETAIL.QtyExpected < RECEIPTDETAIL.QtyReceived THEN 5
                 ELSE 9 END

   OPEN CUR_RECDET

   FETCH NEXT FROM CUR_RECDET INTO  @n_KeyLineNo
                                 ,  @c_Sku
                                 ,  @c_Packkey
                                 ,  @c_UOM
                                 ,  @n_QtyExpected
                                 ,  @n_QtyReceived
                                 ,  @c_lottable07           --CS02
                                 ,  @c_lottable08           --CS02
                                 ,  @c_RDUDF03              --CS04b
                                 ,  @c_Lottable06           --CS04b    


   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @n_QtyVariance = 0
      IF @n_QtyExpected > @n_QtyReceived
      BEGIN
         SET @n_QtyVariance = @n_QtyExpected - @n_QtyReceived
         SET @c_AdjustmentType= @c_AdjustmentType1
         --SET @c_ReasonCode = @c_ShortReasonCode
      END
      ELSE
      BEGIN
         SET @n_QtyVariance = @n_QtyReceived - @n_QtyExpected
         SET @c_AdjustmentType= @c_AdjustmentType2
         --SET @c_ReasonCode = @c_OverReasonCode
      END

      SET @n_Cnt = 1
      IF @n_QtyVariance > 0
      BEGIN
         WHILE @n_Cnt <= 2
         BEGIN
            IF @n_KeyLineNo = 1
            BEGIN
               SET @n_KeyNo = @n_KeyNo + 1
               IF @n_Cnt = 1
               BEGIN

                  SET @n_KeyNo1 = @n_KeyNo
               END
               ELSE
               BEGIN
                  SET @n_KeyNo2 = @n_KeyNo
                  SET @c_AdjustmentType = CASE WHEN @c_AdjustmentType = @c_AdjustmentType1 THEN @c_AdjustmentType2
                                               WHEN @c_AdjustmentType = @c_AdjustmentType2 THEN @c_AdjustmentType1
                                               END
              --SET @c_AdjustmentType = @c_AdjustmentType1
               END

               INSERT INTO #TMP_ADJ
               (  KeyNo
               ,  AdjustmentType
               ,  StorerKey
               ,  Facility
               ,  UserDefine01
               ,  ASNReason                       --(CS02)
               ,  UserDefine02                    --(CS04)
               )
               VALUES
               (  @n_KeyNo
               ,  @c_AdjustmentType
               ,  @c_Storerkey
               ,  @c_Facility
               ,  @c_ReceiptKey
               ,  @c_ASNReason                      --(CS02)
               ,  @c_ExtReckey                      --(CS04)
               )
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 60020
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into #TMP_ADJ Table. (ispASNFZ11)'
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  GOTO QUIT_SP
               END


            END

            IF @n_Cnt = 1
            BEGIN
               SET @n_KeyNo = @n_KeyNo1
            END
            ELSE
            BEGIN
               SET @n_KeyNo = @n_KeyNo2
               SET @n_QtyVariance = @n_QtyVariance * - 1
            END

            SET @c_AdjustmentLineNumber = RIGHT('00000' + CONVERT (NVARCHAR(5), @n_KeyLineNo),5)

            INSERT INTO #TMP_ADJDET
               (  KeyNo
               ,  AdjustmentLineNumber
               ,  StorerKey
               ,  Sku
               ,  Packkey
               ,  UOM
               ,  Lot
               ,  Loc
               ,  Id
               ,  Qty
               ,  ReasonCode
               ,  Lottable05
               ,  Channel
               ,  Lottable07            --CS02
               ,  Lottable08            --CS02
               ,  Lottable01            --CS02
               ,  Lottable02            --CS02
               ,  Lottable03            --CS02
               ,  Lottable04            --CS02
               ,  Lottable06            --CS02
               ,  Lottable09            --CS02
               ,  Lottable10            --CS02
               ,  Lottable11            --CS02
               ,  Lottable12            --CS02
               ,  Lottable13            --CS02
               ,  Lottable14            --CS02
               ,  Lottable15            --CS02
               ,  QtyExpected           --CS02
               ,  QtyReceived           --CS02
               ,  UCCno                 --CS02
               ,  Userdefine03          --CS04b
               )
            VALUES
               (  @n_KeyNo
               ,  @c_AdjustmentLineNumber
               ,  @c_StorerKey
               ,  @c_Sku
               ,  @c_Packkey
               ,  @c_UOM
               ,  ''
               ,  @c_Loc
               ,  ''
               ,  @n_QtyVariance
               ,  @c_ReasonCode
               ,  CONVERT(NVARCHAR(10), GETDATE(), 112)
               ,  'B2B'
               ,  @c_lottable07           --CS02
               ,  @c_lottable08           --CS02
               ,  ''                      --CS02
               ,  ''                      --CS02
               ,  ''                      --CS02
               ,  ''                      --CS02
               ,  @c_Lottable06           --CS02    --CS04b
               ,  ''                      --CS02
               ,  ''                      --CS02
               ,  ''                      --CS02
               ,  ''                      --CS02
               ,  ''                      --CS02
               ,  ''                      --CS02
               ,  ''                      --CS02
               ,  @n_QtyExpected          --CS02
               ,  @n_QtyReceived          --CS02
               ,  ''                      --CS02
               ,  @c_RDUDF03              --CS04b      
               )

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 60030
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into #TMP_ADJDET Table. (ispASNFZ11)'
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO QUIT_SP
            END

            SET @n_Cnt = @n_Cnt + 1
         END
      END

      FETCH NEXT FROM CUR_RECDET INTO  @n_KeyLineNo
                                    ,  @c_Sku
                                    ,  @c_Packkey
                                    ,  @c_UOM
                                    ,  @n_QtyExpected
                                    ,  @n_QtyReceived
                                    ,  @c_lottable07           --CS02
                                    ,  @c_lottable08           --CS02
                                    ,  @c_RDUDF03              --CS04b
                                    ,  @c_Lottable06           --CS04b  
   END
   CLOSE CUR_RECDET
   DEALLOCATE CUR_RECDET

   SET @n_batch = 0
   SELECT @n_batch = COUNT(1)
   FROM #TMP_ADJ
 --print 'chk1'
   IF @n_batch > 0
   BEGIN
      SET @c_AdjustmentKeys = ''
      EXECUTE nspg_GetKey
              @KeyName     = 'ADJUSTMENT'
            , @fieldlength = 10
            , @keystring   = @c_AdjustmentKey   OUTPUT
            , @b_success   = @b_success         OUTPUT
            , @n_err       = @n_err             OUTPUT
            , @c_errmsg    = @c_errmsg          OUTPUT
            , @b_resultset = 0
            , @n_batch     = @n_Batch

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60040
         SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (ispASNFZ11)'
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'
         GOTO QUIT_SP
      END

      UPDATE #TMP_ADJ
         SET AdjustmentKey = RIGHT('0000000000' + CONVERT(NVARCHAR(10), CONVERT(INT, @c_AdjustmentKey) + KeyNo),10)

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60050
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ##TMP_ADJ Table. (ispASNFZ11)'
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END

      UPDATE #TMP_ADJDET
         SET AdjustmentKey = RIGHT('0000000000' + CONVERT(NVARCHAR(10), CONVERT(INT, @c_AdjustmentKey) + KeyNo),10)

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60060
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update #TMP_ADJDET Table. (ispASNFZ11)'
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
      --STEP 1
      --SELECT 'STEP 1 ADJ',* from #TMP_ADJ
      --SELECT 'STEP 1 ADJDET',* from #TMP_ADJDET
      --GOTO QUIT_SP

      DECLARE CUR_ADJ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Adjustmentkey
      FROM   #TMP_ADJ
      ORDER BY Adjustmentkey

      OPEN CUR_ADJ

      FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         INSERT INTO ADJUSTMENT
            (  AdjustmentKey
            ,  AdjustmentType
            ,  StorerKey
            ,  Facility
            ,  UserDefine01
            ,  Userdefine02                  --CS04
            )
         SELECT
               Adjustmentkey
            ,  AdjustmentType
            ,  Storerkey
            ,  Facility
            ,  UserDefine01
            ,  UserDefine02                  --CS04
         FROM #TMP_ADJ
         WHERE Adjustmentkey = @c_Adjustmentkey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60070
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENT Table. (ispASNFZ11)'
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END

         INSERT INTO ADJUSTMENTDETAIL
            (  Adjustmentkey
            ,  AdjustmentLineNumber
            ,  StorerKey
            ,  Sku
            ,  Packkey
            ,  UOM
            ,  Lot
            ,  Loc
            ,  Id
            ,  Qty
            ,  ReasonCode
            ,  Lottable05
            ,  Channel
            ,  Lottable07            --CS02
            ,  Lottable08            --CS02
            ,  Lottable01            --CS02
            ,  Lottable02            --CS02
            ,  Lottable03            --CS02
            ,  Lottable04            --CS02
            ,  Lottable06            --CS02
            ,  Lottable09            --CS02
            ,  Lottable10            --CS02
            ,  Lottable11            --CS02
            ,  Lottable12            --CS02
            ,  Lottable13            --CS02
            ,  Lottable14            --CS02
            ,  Lottable15            --CS02
            ,  UCCNo                 --CS02
            ,  UserDefine03          --CS04b
            )
         SELECT
               AdjustmentKey
            ,  AdjustmentLineNumber
            ,  StorerKey
            ,  Sku
            ,  Packkey
            ,  UOM
            ,  Lot
            ,  Loc
            ,  Id
            ,  Qty
            ,  ReasonCode
            ,  Lottable05
            ,  channel
            ,  Lottable07            --CS02
            ,  Lottable08            --CS02
            ,  Lottable01            --CS02
            ,  Lottable02            --CS02
            ,  Lottable03            --CS02
            ,  Lottable04            --CS02
            ,  Lottable06            --CS02
            ,  Lottable09            --CS02
            ,  Lottable10            --CS02
            ,  Lottable11            --CS02
            ,  Lottable12            --CS02
            ,  Lottable13            --CS02
            ,  Lottable14            --CS02
            ,  Lottable15            --CS02
            ,  UccNo                 --CS02
            , Userdefine03           --CS04b
         FROM #TMP_ADJDET
         WHERE Adjustmentkey = @c_Adjustmentkey
         ORDER BY AdjustmentLineNumber

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60080
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENTDETAIL Table. (ispASNFZ11)'
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
      END
      CLOSE CUR_ADJ
      DEALLOCATE CUR_ADJ
   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   --STEP 2
   --CS02 START


--select 'STEP 1 ' , @c_ASNReason '@c_ASNReason'
  --select * from #TMP_ADJ
  --select * from #TMP_ADJDET

  --GOTO QUIT_SP
  IF @c_ASNReason = 'TRF'
  BEGIN

   --SELECT 'START STEP 2'

   SET @c_Lot01 = ''
   SET @c_Lot02 = ''
   SET @c_Lot03 = ''
   SET @d_Lot04 = NULL
   SET @d_Lot05 = NULL
   SET @c_Lot06 = ''
   SET @c_Lot07 = ''
   SET @c_Lot08 = ''
   SET @c_Lot09 = ''
   SET @c_Lot10 = ''
   SET @c_Lot11 = ''
   SET @c_Lot12 = ''
   SET @d_Lot13 = NULL
   SET @d_Lot14 = NULL
   SET @d_Lot15 = NULL

  BEGIN TRAN

  SET @n_KeyNo = 1
  SET @c_AdjustmentType = 'TRF'

   INSERT INTO #TMP_ADJ
               (  KeyNo
               ,  AdjustmentType
               ,  StorerKey
               ,  Facility
               ,  UserDefine01
               ,  ASNReason                       --(CS02)
               ,  UserDefine02                    --(CS04)
               )
               VALUES
               (  @n_KeyNo
               ,  @c_AdjustmentType              --(CS02)
               ,  @c_Storerkey
               ,  @c_Facility
               ,  @c_ReceiptKey
               ,  @c_ASNReason                   --(CS02)
               ,  @c_ExtReckey                   --(CS04) 
               )
               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 60020
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into #TMP_ADJ Table. (ispASNFZ11 Step 2)'
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  GOTO QUIT_SP
               END


   DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT KeyLineNo = ROW_NUMBER() OVER (PARTITION BY RECEIPTDETAIL.ReceiptKey
                                        --, CASE WHEN RECEIPTDETAIL.QtyExpected <> RECEIPTDETAIL.QtyReceived THEN 0
                                        -- -- WHEN RECEIPTDETAIL.QtyExpected < RECEIPTDETAIL.QtyReceived THEN 5
                                        --  ELSE 9 END
                                          ORDER BY ReceiptLineNumber )
                                          --CASE WHEN RECEIPTDETAIL.QtyExpected <> RECEIPTDETAIL.QtyReceived THEN 0
                                          --  --   WHEN RECEIPTDETAIL.QtyExpected < RECEIPTDETAIL.QtyReceived THEN 5
                                          --     ELSE 9 END)
         ,RECEIPTDETAIL.Sku
         ,RECEIPTDETAIL.Packkey
         ,RECEIPTDETAIL.UOM
         ,RECEIPTDETAIL.QtyExpected
         ,RECEIPTDETAIL.QtyReceived
         ,RECEIPTDETAIL.ToId
         ,RECEIPTDETAIL.ReceiptLineNumber
         ,RECEIPTDETAIL.Toloc
         ,RECEIPTDETAIL.Userdefine01
         ,RECEIPTDETAIL.Userdefine03                             --CS04b
   FROM   RECEIPTDETAIL WITH (NOLOCK)
   WHERE  RECEIPTDETAIL.ReceiptKey = @c_ReceiptKey
   AND RECEIPTDETAIL.QtyReceived > 0 --AND (RECEIPTDETAIL.QtyExpected <> RECEIPTDETAIL.QtyReceived)
   ORDER BY RECEIPTDETAIL.ReceiptLineNumber
   --ORDER BY CASE WHEN RECEIPTDETAIL.QtyExpected > RECEIPTDETAIL.QtyReceived THEN 0
   --              WHEN RECEIPTDETAIL.QtyExpected < RECEIPTDETAIL.QtyReceived THEN 5
   --              ELSE 9 END

   OPEN CUR_RECDET

   FETCH NEXT FROM CUR_RECDET INTO  @n_KeyLineNo
                                 ,  @c_Sku
                                 ,  @c_Packkey
                                 ,  @c_UOM
                                 ,  @n_QtyExpected
                                 ,  @n_QtyReceived
                                 ,  @c_toid
                                 ,  @c_RDLineNo
                                 ,  @c_toloc
                                 ,  @c_RDUDF01
                                 ,  @c_RDUDF03              --CS04b


   WHILE @@FETCH_STATUS <> -1
   BEGIN

      --SET @n_QtyVariance = 0
      --IF @n_QtyExpected > @n_QtyReceived
      --BEGIN
      --   SET @n_QtyVariance = @n_QtyExpected - @n_QtyReceived
      --   SET @c_AdjustmentType= @c_AdjustmentType1
      --   --SET @c_ReasonCode = @c_ShortReasonCode
      --END
      --ELSE
      --BEGIN
      --   SET @n_QtyVariance = @n_QtyReceived - @n_QtyExpected
      --   SET @c_AdjustmentType= @c_AdjustmentType2
      --   --SET @c_ReasonCode = @c_OverReasonCode
      --END
       SET @c_lot = ''

       SELECT TOP 1 @c_lot = ITRN.LOT
                  -- ,@c_itrnLoc = ITRN.toloc
       FROM ITRN ITRN WITH (NOLOCK)
       --JOIN ADJUSTMENTDETAIL AJD WITH (NOLOCK) ON AJD.AdjustmentKey = ADJ.AdjustmentKey
       WHERE ITRN.sourcekey = @c_ReceiptKey + @c_RDLineNo
       AND ITRN.SKU = @c_Sku
       AND ITRN.sourcetype = 'ntrReceiptDetailUpdate'

       IF ISNULL(@c_lot,'' ) <> ''
       BEGIN
       SELECT TOP 1  @c_Lot01 = ISNULL(LOTT.lottable01,'')
             ,@c_Lot02 = ISNULL(LOTT.lottable02,'')
             ,@c_Lot03 = ISNULL(LOTT.lottable03,'')
             ,@d_Lot04 = ISNULL(LOTT.lottable04,'')
             ,@d_Lot05 = ISNULL(LOTT.lottable05,'')
             ,@c_Lot06 = ISNULL(LOTT.lottable06,'')
             ,@c_Lot07 = ISNULL(LOTT.lottable07,'')
             ,@c_Lot08 = ISNULL(LOTT.lottable08,'')
             ,@c_Lot09 = ISNULL(LOTT.lottable09,'')
             ,@c_Lot10 = ISNULL(LOTT.lottable10,'')
             ,@c_Lot11 = ISNULL(LOTT.lottable11,'')
             ,@c_Lot12 = ISNULL(LOTT.lottable12,'')
             ,@d_Lot13 = ISNULL(LOTT.lottable13,'')
             ,@d_Lot14 = ISNULL(LOTT.lottable14,'')
             ,@d_Lot15 = ISNULL(LOTT.lottable15,'')
       FROM lotattribute LOTT WITH (NOLOCK)
       WHERE LOTT.lot = @c_lot

       END
      ELSE
      BEGIN
        SELECT TOP 1  @c_Lot01 = ISNULL(RECEIPTDETAIL.lottable01,'')
             ,@c_Lot02 = ISNULL(RECEIPTDETAIL.lottable02,'')
             ,@c_Lot03 = ISNULL(RECEIPTDETAIL.lottable03,'')
             ,@d_Lot04 = ISNULL(RECEIPTDETAIL.lottable04,'')
             ,@d_Lot05 = ISNULL(RECEIPTDETAIL.lottable05,'')
             ,@c_Lot06 = ISNULL(RECEIPTDETAIL.lottable06,'')
             ,@c_Lot07 = ISNULL(RECEIPTDETAIL.lottable07,'')
             ,@c_Lot08 = ISNULL(RECEIPTDETAIL.lottable08,'')
             ,@c_Lot09 = ISNULL(RECEIPTDETAIL.lottable09,'')
             ,@c_Lot10 = ISNULL(RECEIPTDETAIL.lottable10,'')
             ,@c_Lot11 = ISNULL(RECEIPTDETAIL.lottable11,'')
             ,@c_Lot12 = ISNULL(RECEIPTDETAIL.lottable12,'')
             ,@d_Lot13 = ISNULL(RECEIPTDETAIL.lottable13,'')
             ,@d_Lot14 = ISNULL(RECEIPTDETAIL.lottable14,'')
             ,@d_Lot15 = ISNULL(RECEIPTDETAIL.lottable15,'')
       FROM RECEIPTDETAIL RECEIPTDETAIL WITH (NOLOCK)
       WHERE RECEIPTDETAIL.Receiptkey = @c_ReceiptKey
       AND  RECEIPTDETAIL.SKU=@c_Sku
      END

      --SET @n_Cnt = 1
      --IF @n_QtyVariance > 0
      --BEGIN
      --   WHILE @n_Cnt <= 2
      --   BEGIN
      --      IF @n_KeyLineNo = 1
      --      BEGIN
      --         SET @n_KeyNo = @n_KeyNo + 1
      --         IF @n_Cnt = 1
      --         BEGIN

      --            SET @n_KeyNo1 = @n_KeyNo
      --         END
      --         ELSE
      --         BEGIN
      --            SET @n_KeyNo2 = @n_KeyNo
      --            SET @c_AdjustmentType = CASE WHEN @c_AdjustmentType = @c_AdjustmentType1 THEN @c_AdjustmentType2
      --                                         WHEN @c_AdjustmentType = @c_AdjustmentType2 THEN @c_AdjustmentType1
      --                                         END
              ----SET @c_AdjustmentType = @c_AdjustmentType1
      --         END




        --    END

            --IF @n_Cnt = 1
            --BEGIN
            --   SET @n_KeyNo = @n_KeyNo1
            --END
            --ELSE
            --BEGIN
            --   SET @n_KeyNo = @n_KeyNo2
            --   SET @n_QtyVariance = @n_QtyVariance * - 1
            --END

            SET @c_AdjustmentLineNumber = RIGHT('00000' + CONVERT (NVARCHAR(5), @n_KeyLineNo),5)

            INSERT INTO #TMP_ADJDET
               (  KeyNo
               ,  AdjustmentLineNumber
               ,  StorerKey
               ,  Sku
               ,  Packkey
               ,  UOM
               ,  Lot
               ,  Loc
               ,  Id
               ,  Qty
               ,  ReasonCode
               ,  Lottable05
               ,  Channel
               ,  Lottable01
               ,  Lottable02
               ,  Lottable03
               ,  Lottable04
          --     ,  Lottable05
               ,  Lottable06
               ,  Lottable07
               ,  Lottable08
               ,  Lottable09
               ,  Lottable10
               ,  Lottable11
               ,  Lottable12
               ,  Lottable13
               ,  Lottable14
               ,  Lottable15
               ,  UCCNo
               ,  Userdefine03                  --CS04a
               )
            VALUES
               (  @n_KeyNo
               ,  @c_AdjustmentLineNumber
               ,  @c_StorerKey
               ,  @c_Sku
               ,  @c_Packkey
               ,  @c_UOM
               ,  @c_lot
               ,  @c_toLoc
               ,  @c_Toid
               ,  (-1*@n_QtyReceived)
               ,  'TF'
               --,  CONVERT(NVARCHAR(10), GETDATE(), 112)
               ,  @d_Lot05
               ,  'B2C'
               ,  ISNULL(@c_Lot01,'')
               ,  ISNULL(@c_Lot02,'')
               ,  ISNULL(@c_Lot03,'')
               ,  ISNULL(@d_Lot04,'')
              -- ,  @d_Lot05
               ,  ISNULL(@c_Lot06,'')
               ,  ISNULL(@c_Lot07,'')
               ,  ISNULL(@c_Lot08,'')
               ,  ISNULL(@c_Lot09,'')
               ,  ISNULL(@c_Lot10,'')
               ,  ISNULL(@c_Lot11,'')
               ,  ISNULL(@c_Lot12,'')
               ,  ISNULL(@d_Lot13,'')
               ,  ISNULL(@d_Lot14,'')
               ,  ISNULL(@d_Lot15,'')
               ,  @c_RDUDF01
               ,  @c_RDUDF03                         --CS04b
               )

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 60030
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into #TMP_ADJDET Table. (ispASNFZ11 Step 2)'
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO QUIT_SP
            END

          --  SET @n_Cnt = @n_Cnt + 1
       --  END
     -- END

      FETCH NEXT FROM CUR_RECDET INTO  @n_KeyLineNo
                                    ,  @c_Sku
                                    ,  @c_Packkey
                                    ,  @c_UOM
                                    ,  @n_QtyExpected
                                    ,  @n_QtyReceived
                                    ,  @c_Toid
                                    ,  @c_RDLineNo
                                    ,  @c_toloc
                                    ,  @c_RDUDF01
                                    ,  @c_RDUDF03              --CS04b
   END
   CLOSE CUR_RECDET
   DEALLOCATE CUR_RECDET

  -- select 'adjdet',* from #TMP_ADJDET

     --SELECT 'STEP 2 ADJ',* from #TMP_ADJ
     --SELECT 'STEP 2 ADJDET',* from #TMP_ADJDET
     --GOTO QUIT_SP

   SET @n_batch = 0
   SELECT @n_batch = COUNT(1)
   FROM #TMP_ADJ
   WHERE ASNReason = 'TRF'
   AND AdjustmentType = 'TRF'

   IF @n_batch > 0
   BEGIN
      SET @c_AdjustmentKeys = ''
      EXECUTE nspg_GetKey
              @KeyName     = 'ADJUSTMENT'
            , @fieldlength = 10
            , @keystring   = @c_AdjustmentKey   OUTPUT
            , @b_success   = @b_success         OUTPUT
            , @n_err       = @n_err             OUTPUT
            , @c_errmsg    = @c_errmsg          OUTPUT
            , @b_resultset = 0
            , @n_batch     = @n_Batch

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60040
         SET @c_errmsg='NSQL'+ CONVERT(CHAR(5),@n_err)+': Error Executing nspg_GetKey. (ispASNFZ11 Step 2)'
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ).'
         GOTO QUIT_SP
      END

      UPDATE #TMP_ADJ
         SET AdjustmentKey = RIGHT('0000000000' + CONVERT(NVARCHAR(10), CONVERT(INT, @c_AdjustmentKey) + KeyNo),10)
      WHERE AdjustmentType ='TRF' AND ASNReason = 'TRF'

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60050
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ##TMP_ADJ Table. (ispASNFZ11 Step 2)'
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END

      UPDATE #TMP_ADJDET
         SET AdjustmentKey = RIGHT('0000000000' + CONVERT(NVARCHAR(10), CONVERT(INT, @c_AdjustmentKey) + KeyNo),10)
      WHERE Channel = 'B2C'

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60060
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update #TMP_ADJDET Table. (ispASNFZ11  Step 2)'
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END

     --SELECT 'STEP 2 Update ADJ',* from #TMP_ADJ
     --SELECT 'STEP 2 Update ADJDET',* from #TMP_ADJDET
     --GOTO QUIT_SP

      DECLARE CUR_ADJ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Adjustmentkey
      FROM   #TMP_ADJ
      WHERE ASNReason = 'TRF'
      AND AdjustmentType = 'TRF'
      ORDER BY Adjustmentkey

      OPEN CUR_ADJ

      FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         INSERT INTO ADJUSTMENT
            (  AdjustmentKey
            ,  AdjustmentType
            ,  StorerKey
            ,  Facility
            ,  UserDefine01
            ,  Userdefine02
            )
         SELECT
               Adjustmentkey
            ,  AdjustmentType
            ,  Storerkey
            ,  Facility
            ,  UserDefine01
            ,  'B2C2B2B'
         FROM #TMP_ADJ
         WHERE Adjustmentkey = @c_Adjustmentkey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60070
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENT Table. (ispASNFZ11  Step 2)'
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END

         INSERT INTO ADJUSTMENTDETAIL
            (  Adjustmentkey
            ,  AdjustmentLineNumber
            ,  StorerKey
            ,  Sku
            ,  Packkey
            ,  UOM
            ,  Lot
            ,  Loc
            ,  Id
            ,  Qty
            ,  ReasonCode
            ,  Lottable05
            ,  Channel
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
         --     ,  Lottable05
            ,  Lottable06
            ,  Lottable07
            ,  Lottable08
            ,  Lottable09
            ,  Lottable10
            ,  Lottable11
            ,  Lottable12
            ,  Lottable13
            ,  Lottable14
            ,  Lottable15
            ,  UccNo
            ,  UserDefine03                       --CS04b
            )
         SELECT
               AdjustmentKey
            ,  AdjustmentLineNumber
            ,  StorerKey
            ,  Sku
            ,  Packkey
            ,  UOM
            ,  Lot
            ,  Loc
            ,  Id
            ,  Qty
            ,  ReasonCode
            ,  Lottable05
            ,  Channel
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
         --     ,  Lottable05
            ,  Lottable06
            ,  Lottable07
            ,  Lottable08
            ,  Lottable09
            ,  Lottable10
            ,  Lottable11
            ,  Lottable12
            ,  Lottable13
            ,  Lottable14
            ,  Lottable15
            ,  UccNo
            ,  Userdefine03                              --CS04b
         FROM #TMP_ADJDET
         WHERE Adjustmentkey = @c_Adjustmentkey
         ORDER BY AdjustmentLineNumber

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 60080
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert into ADJUSTMENTDETAIL Table. (ispASNFZ11 Step 2)'
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
      END
      CLOSE CUR_ADJ
      DEALLOCATE CUR_ADJ
   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

  END

   --CS02 END
  --select * from #TMP_ADJDET

   DECLARE CUR_ADJ CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Adjustmentkey
   FROM   #TMP_ADJ
   ORDER BY Adjustmentkey

   OPEN CUR_ADJ

   FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXECUTE isp_FinalizeADJ
               @c_ADJKey   = @c_AdjustmentKey
            ,  @b_Success  = @b_Success OUTPUT
            ,  @n_err      = @n_err     OUTPUT
            ,  @c_errmsg   = @c_errmsg  OUTPUT

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err  = 60090
         SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Execute isp_FinalizeADJ Failed. (ispASNFZ11)'
         GOTO QUIT_SP
      END

      SET @n_Cnt = 0

      SELECT @n_Cnt = 1
      FROM ADJUSTMENTDETAIL WITH (NOLOCK)
      WHERE AdjustmentKey = @c_AdjustmentKey
      AND FinalizedFlag <> 'Y'

      --IF @n_Cnt = 0
      --BEGIN
      --   UPDATE ADJUSTMENT WITH (ROWLOCK)
      --   SET FinalizedFlag = 'Y'
      --   WHERE AdjustmentKey = @c_AdjustmentKey


      --   IF @n_err <> 0
      --   BEGIN
      --      SET @n_continue= 3
      --      SET @n_err  = 60090
      --      SET @c_errmsg = 'NSQL'+ CONVERT(CHAR(5),@n_err)+': Execute isp_FinalizeADJ Failed. (ispASNFZ11)'
      --      GOTO QUIT_SP
      --   END
      --END

      FETCH NEXT FROM CUR_ADJ INTO @c_Adjustmentkey
   END
   CLOSE CUR_ADJ
   DEALLOCATE CUR_ADJ
   --CS01 End
   QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_RECDET') in (0 , 1)
   BEGIN
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET
   END


   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT > @n_StartTCnt AND @@TRANCOUNT = 1
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispASNFZ11'
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

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

END

GO