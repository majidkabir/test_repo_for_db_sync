SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Stored Procedure: msp_ULACalcShelfLife                                        */
/* Creation Date  :                                                              */
/* Copyright      : Maersk Logisitic                                             */
/* Written by     : Wan                                                          */
/*                                                                               */
/* Purpose:                                                                      */
/*                                                                               */
/* Called from: 1 (Stock Take )                                                  */
/*    1. From scheduler                                                          */
/*                                                                               */
/* Version: 1.2                                                                  */
/*                                                                               */
/* Data Modifications:                                                           */
/*                                                                               */
/* Updates:                                                                      */
/* Date        Author   Ver.  Purposes                                           */
/* 2025-01-21  Wan01    1.1   UWP-29372 - [FCR-1953] [Unilever] Modify Shelf Life*/
/*                            Code Calculation Function                          */
/* 2025-02-27  Wan02    1.2   UWP-30082[FCR-2681] - ShelfLife Code Base on       */
/*                            Configurable SkuGroup                              */
/*********************************************************************************/

CREATE   PROC msp_ULACalcShelfLife (
  @c_StorerKey     NVARCHAR(15)
, @c_TranType      NVARCHAR(12) = ''
, @b_debug         int      = 0
, @b_Success       int       = 0     OUTPUT
, @n_err           int       = 0     OUTPUT
, @c_errmsg        NVARCHAR(250) = NULL  OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_NULLS OFF;
    SET QUOTED_IDENTIFIER OFF;
    SET CONCAT_NULL_YIELDS_NULL OFF;

    /*********************************************/
    /* Variables Declaration (Start)             */
    /*********************************************/
    DECLARE
        @n_continue  int
        , @n_StartTCnt int;

    SET @n_continue = 1;
    SET @n_StartTCnt = @@TRANCOUNT;
    SET @c_errmsg = '';

    -- General
    DECLARE
        @d_Getdate              DATETIME = GETDATE()
        , @c_Getdate            NVARCHAR(10)
        , @c_Listname           NVARCHAR(10)
        , @n_Check              INT = 0
        , @c_Status0            NVARCHAR(10) = '0';

    -- Header Records
    DECLARE @c_TransferKey      NVARCHAR(10)
        , @c_Facility           NVARCHAR(5)
        , @n_MaxLines           int     = 3000
        , @n_TotalLines         int     = 0;

    -- Detail Records
    DECLARE @c_TransferLineNumber   NVARCHAR(5)
        , @c_SKU                    NVARCHAR(20)
        , @c_Loc                    NVARCHAR(10)
        , @c_Lot                    NVARCHAR(10)
        , @c_ID                     NVARCHAR(18)
        , @n_Qty                    INT = 0
        , @c_PACKKey                NVARCHAR(10) = ''
        , @c_UOM                    NVARCHAR(10) = ''
        , @c_Lottable01             NVARCHAR(18) = ''
        , @c_Lottable02             NVARCHAR(18) = ''
        , @c_Lottable03             NVARCHAR(18) = ''
        , @d_Lottable04             DATETIME
        , @d_Lottable05             DATETIME
        , @c_Lottable06             NVARCHAR(30) = ''
        , @c_ToLottable06           NVARCHAR(30) = ''
        , @c_Lottable07             NVARCHAR(30) = ''
        , @c_Lottable08             NVARCHAR(30) = ''
        , @c_Lottable09             NVARCHAR(30) = ''
        , @c_Lottable10             NVARCHAR(30) = ''
        , @c_Lottable11             NVARCHAR(30) = ''
        , @c_Lottable12             NVARCHAR(30) = ''
        , @d_Lottable13             DATETIME
        , @d_Lottable14             DATETIME
        , @d_Lottable15             DATETIME
        , @c_ShelfLife              NVARCHAR(30) = ''
        , @c_ShelfLifeFnc           NVARCHAR(20) = ''
        , @c_ConfigKey              NVARCHAR(20) = 'ShelfLifeCalcFnc'
        , @c_ReasonCode             NVARCHAR(10) = '';


    SET @c_Listname = 'TRANTYPE'
    /*********************************************/
    /* Variables Declaration (End)               */
    /*********************************************/
    CREATE TABLE #TRANSFER_TRK
    (
        RowID INT IDENTITY(1, 1) PRIMARY KEY,
        TransferKey NVARCHAR(10)
    );

    /*********************************************/
    /* Main Validation (Start)                   */
    /*********************************************/

    IF ISNULL(RTRIM(@c_TranType), '') = ''
     BEGIN
         SET @n_continue = 3
         SET @n_Err = 562551
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                       + ': Transfer Type Parameter is Required. (msp_ULACalcShelfLife)'
         GOTO QUIT
     END

    SELECT
        @n_Check = 1
    FROM CODELKUP WITH (NOLOCK)
    WHERE Listname = @c_Listname AND Code = @c_TranType


    IF @n_Check <> 1
     BEGIN
         SET @n_continue = 3
         SET @n_Err = 562552
         SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) +
                         ': CODELKUP Setup not exists(For Type). Listname:' + ISNULL(RTRIM(@c_Listname), '') 
                       + ' , Code:' + ISNULL(RTRIM(@c_TranType), '') + ' (msp_ULACalcShelfLife)'
         GOTO QUIT
     END

    SET @n_Check = 0;
    SELECT TOP 1
        @c_ReasonCode = Code2
    FROM dbo.CODELKUP CLK WITH (NOLOCK)
    WHERE Listname = @c_Listname
      AND CLK.Storerkey = @c_StorerKey
      AND CLK.Code = @c_TranType;

    IF ISNULL(RTRIM(@c_ReasonCode), '') = ''
     BEGIN
         SET @n_continue = 3;
         SET @n_err = 68003;
         SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) +
                         ': CODELKUP.Short Setup not exists(For Reason Code). Listname:' + ISNULL(RTRIM(@c_Listname), '') 
                       + ', Code:' + ISNULL(RTRIM(@c_ReasonCode), '') + ' (msp_ULACalcShelfLife)';
         GOTO QUIT;
     END;

    SELECT TOP 1 @c_ShelfLifeFnc = SValue
    FROM dbo.StorerConfig WITH (NOLOCK)
    WHERE ConfigKey = @c_ConfigKey AND Storerkey = @c_StorerKey
    IF ISNULL(RTRIM(@c_ShelfLifeFnc), '') = ''
     BEGIN
         SET @n_continue = 3;
         SET @n_err = 68003;
         SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) +
                         ': StorerConfig.SValue does not exist. For ConfigKey:' 
                       + ISNULL(RTRIM(@c_ConfigKey), '') + ', Storerkey:' + ISNULL(RTRIM(@c_StorerKey), '') 
                       + ' (msp_ULACalcShelfLife)';
         GOTO QUIT;
     END;

    /*********************************************/
    /* Main Validation (END)                     */
    /*********************************************/

    /*******************************************************/
    /* Insert Transfer Records - (Start)                   */
    /*******************************************************/
     IF @n_continue = 1 OR @n_continue = 2
      BEGIN
          SET @c_Facility   = '';
          -- Retrieve related info from inventory table into a cursor
          DECLARE CUR_TRANSFER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
              SELECT DISTINCT LOC.Facility, LA.Sku, LA.Lottable04, LA.Lottable07, LA.Lottable13
              FROM dbo.LOT WITH (NOLOCK)
              JOIN dbo.LOTAttribute AS LA WITH (NOLOCK, INDEX(PKLOTAttribute) ) ON (LOT.Lot = LA.LOT)
              JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON LLI.Lot = LOT.Lot
              JOIN dbo.LOC WITH (NOLOCK) ON LOC.Loc = LLI.Loc
              JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.StorerKey = LOT.StorerKey AND SKU.SKU = LOT.Sku
              JOIN dbo.CODELKUP WITH (NOLOCK) ON  Codelkup.ListName = 'SLSKUGROUP'  --(Wan02)
                                              AND Codelkup.Code = SKU.SKUGROUP      --(Wan02)
              WHERE LOT.StorerKey = @c_StorerKey
                AND (LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked) > 0
                AND LA.Lottable06 in ( '0' , '')
                --AND SKU.SKUGROUP IN ('FG', 'RM', 'PC');                           --(Wan02)            
          OPEN CUR_TRANSFER;
          FETCH NEXT FROM CUR_TRANSFER INTO @c_Facility, @c_SKU, @d_Lottable04, @c_Lottable07, @d_Lottable13;
          WHILE @@FETCH_STATUS <> -1
           BEGIN
               -- Calculate new Shelf Life
               IF @c_ShelfLifeFnc = 'fnc_CalcShelfLifeBUL'
               BEGIN
                 SELECT @c_ShelfLife =  dbo.fnc_CalcShelfLifeBUL(@c_StorerKey, @c_SKU, @d_Lottable04);
               END
               ELSE IF @c_ShelfLifeFnc = 'fnc_CalcShelfLifeBUD'
               BEGIN
                 SELECT @c_ShelfLife =  dbo.fnc_CalcShelfLifeBUD(@c_StorerKey, @c_SKU, @d_Lottable04, @d_Lottable13);
               END
               -- If Lottable07 not required to change, getting next record
               IF @c_ShelfLife = @c_Lottable07
                   GOTO NextRecord;
               IF @n_TotalLines <= @n_MaxLines
                BEGIN
                    SET @n_TotalLines = 0;
                    BEGIN TRAN;
                    SELECT @b_success = 0;
                    EXECUTE   nspg_getkey
                        'TRANSFER'
                        , 10
                        , @c_TransferKey OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT;
                    IF @b_debug = 1
                     BEGIN
                         print @c_TransferKey;
                     END;
                    IF @b_success = 1
                     BEGIN
                         INSERT INTO Transfer (TransferKey,
                                               FromStorerKey,
                                               ToStorerKey,
                                               Type,
                                               OpenQty,
                                               Status,
                                               EffectiveDate,
                                               ReasonCode,
                                               CustomerRefNo,
                                               Facility,
                                               ToFacility)
                         VALUES (@c_TransferKey,
                                 ISNULL(RTRIM(@c_StorerKey), ''),
                                 ISNULL(RTRIM(@c_StorerKey), ''),
                                 ISNULL(RTRIM(@c_TranType), ''),
                                 0,
                                 @c_Status0,
                                 @d_Getdate,
                                 ISNULL(RTRIM(@c_ReasonCode), ''),
                                 ISNULL(RTRIM(@c_Getdate), ''),
                                 ISNULL(RTRIM(@c_Facility), ''),
                                 ISNULL(RTRIM(@c_Facility), ''));

                         IF @@ERROR = 0
                             BEGIN
                                 WHILE @@TRANCOUNT > 0
                                     COMMIT TRAN;

                                 IF @b_debug = 1
                                     BEGIN
                                         SELECT 'Insert Records Into Transfer table is Done!';
                                     END;
                                 INSERT INTO #TRANSFER_TRK (TransferKey) VALUES (@c_TransferKey);
                             END;
                         ELSE
                             BEGIN
                                 SET @n_continue = 3;
                                 SET @n_err = 562553;
                                 SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) +
                                                 ': Insert into Transfer Table failed. (msp_ULACalcShelfLife)';
                                 GOTO QUIT;
                             END;
                     END; -- @b_success = 1
                     ELSE
                     BEGIN
                         SET @n_continue = 3;
                         SET @n_err = 562554;
                         SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) +
                                         ': Generate Transfer Key Failed. (msp_ULACalcShelfLife)';
                         GOTO QUIT;
                     END; -- @b_success = 1
                     SET @c_TransferLineNumber  = '';
                END; -- @n_TotalLines >= @n_MaxLines

               /***********************************************/
               /* Insert TransferDetail (Start)               */
               /***********************************************/
               IF @n_continue = 1 OR @n_Continue = 2
                BEGIN
                    SET @c_Loc                 = '';
                    SET @c_Lot                 = '';
                    SET @c_ID                  = '';
                    SET @n_Qty                 = 0;
                    SET @c_PACKKey             = '';
                    SET @c_UOM                 = '';
                    SET @c_Lottable01          = '';
                    SET @c_Lottable02          = '';
                    SET @d_Lottable05          = '';
                    SET @c_Lottable06          = '';
                    SET @c_ToLottable06        = '';  
                    SET @c_Lottable08          = '';
                    SET @c_Lottable09          = '';
                    SET @c_Lottable10          = '';
                    SET @c_Lottable11          = '';
                    SET @c_Lottable12          = '';
                    SET @d_Lottable13          = '';
                    SET @d_Lottable14          = '';
                    SET @d_Lottable15          = '';

                    -- Retrieve related info from inventory table into a cursor
                    DECLARE CUR_TRANSFERDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT 
                            LLI.SKU,
                            LLI.Loc,
                            LLI.Lot,
                            LLI.ID,
                            LLI.Qty,
                            SKU.PACKKey,
                            PACK.PackUOM3,
                            LA.Lottable01,
                            LA.Lottable02,
                            LA.Lottable03,
                            LA.Lottable04,
                            LA.Lottable05,
                            LA.Lottable06,
                            LA.Lottable07,
                            LA.Lottable08,
                            LA.Lottable09,
                            LA.Lottable10,
                            LA.Lottable11,
                            LA.Lottable12,
                            LA.Lottable13,
                            LA.Lottable14,
                            LA.Lottable15
                        FROM LOTxLOCxID LLI WITH (NOLOCK)
                            JOIN LOC WITH (NOLOCK) ON ( LLI.Loc = LOC.LOC)
                            JOIN LOTAttribute LA WITH (NOLOCK, INDEX(PKLOTAttribute) ) ON (LLI.Lot = LA.LOT)
                            JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                            JOIN PACK WITH (NOLOCK) ON (SKU.PACKKey = PACK.PACKKey)
                            JOIN LOT WITH (NOLOCK) ON ( LLI.LOT = LOT.LOT)
                        WHERE LLI.StorerKey = @c_StorerKey
                            AND LLI.Sku = @c_SKU
                            AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
                            AND LOC.Facility = @c_Facility
                            AND LA.Lottable04 = @d_Lottable04
                            AND LA.Lottable06 in ( '0' , '')
                            AND LA.Lottable07 = @c_Lottable07;

                    OPEN CUR_TRANSFERDETAIL;

                    FETCH NEXT FROM CUR_TRANSFERDETAIL INTO  
                        @c_SKU,        @c_Loc,        @c_Lot,        @c_ID,         @n_Qty,        @c_PACKKey,
                        @c_UOM,        @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                        @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                        @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15;
                    WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        SELECT @c_TransferLineNumber = MAX(TransferLineNumber)
                        FROM dbo.TransferDetail WITH (NOLOCK)
                        WHERE TransferKey = @c_TransferKey;

                        SET @c_TransferLineNumber = RIGHT('0000' + RTRIM(CAST(CAST(ISNULL(@c_TransferLineNumber,0) AS int) 
                                                                 + 1 AS NVARCHAR(5))),5);

                        IF @c_ShelfLife = 'ML51' or @c_ShelfLife = 'ML49' --or @c_ShelfLife = 'ML13' or @c_ShelfLife = 'ML18'   --(Wan01)
                          SET @c_ToLottable06 = '1'
                        ELSE
                          SET @c_ToLottable06 = @c_Lottable06

                         BEGIN TRAN;
                          INSERT INTO TransferDetail (
                              TransferKey,
                              TransferLineNumber,
                              FromStorerKey,
                              FromSku,
                              FromLoc,
                              FromLot,
                              FromId,
                              FromQty,
                              FromPackKey,
                              FromUOM,
                              Lottable01,
                              Lottable02,
                              Lottable03,
                              Lottable04,
                              Lottable05,
                              Lottable06,
                              Lottable07,
                              Lottable08,
                              Lottable09,
                              Lottable10,
                              Lottable11,
                              Lottable12,
                              Lottable13,
                              Lottable14,
                              Lottable15,
                              ToStorerKey,
                              ToSku,
                              ToLoc,
                              --ToLot, Must Blank, else trigger cant EXECUTE
                              ToId,
                              ToQty,
                              ToPackKey,
                              ToUOM,
                              Status,
                              EffectiveDate,
                              ToLottable01,
                              ToLottable02,
                              ToLottable03,
                              ToLottable04,
                              ToLottable05,
                              ToLottable06,
                              ToLottable07,
                              ToLottable08,
                              ToLottable09,
                              ToLottable10,
                              ToLottable11,
                              ToLottable12,
                              ToLottable13,
                              ToLottable14,
                              ToLottable15
                          ) VALUES (
                              @c_TransferKey,
                              @c_TransferLineNumber,
                              ISNULL(RTRIM(@c_StorerKey), ''),
                              ISNULL(RTRIM(@c_SKU), ''),
                              ISNULL(RTRIM(@c_Loc), ''),
                              ISNULL(RTRIM(@c_Lot), ''),
                              ISNULL(RTRIM(@c_ID), ''),
                              ISNULL(RTRIM(@n_Qty), 0),
                              ISNULL(RTRIM(@c_PACKKey), ''),
                              ISNULL(RTRIM(@c_UOM), ''),
                              ISNULL(RTRIM(@c_Lottable01), ''),
                              ISNULL(RTRIM(@c_Lottable02), ''),
                              ISNULL(RTRIM(@c_Lottable03), ''),
                              ISNULL(RTRIM(@d_Lottable04), ''),
                              ISNULL(RTRIM(@d_Lottable05), ''),
                              ISNULL(RTRIM(@c_Lottable06), ''),
                              ISNULL(RTRIM(@c_Lottable07), ''),
                              ISNULL(RTRIM(@c_Lottable08), ''),
                              ISNULL(RTRIM(@c_Lottable09), ''),
                              ISNULL(RTRIM(@c_Lottable10), ''),
                              ISNULL(RTRIM(@c_Lottable11), ''),
                              ISNULL(RTRIM(@c_Lottable12), ''),
                              ISNULL(RTRIM(@d_Lottable13), ''),
                              ISNULL(RTRIM(@d_Lottable14), ''),
                              ISNULL(RTRIM(@d_Lottable15), ''),
                              ISNULL(RTRIM(@c_StorerKey), ''),
                              ISNULL(RTRIM(@c_SKU), ''),
                              ISNULL(RTRIM(@c_Loc), ''),
                              ISNULL(RTRIM(@c_ID), ''),
                              ISNULL(RTRIM(@n_Qty), 0),
                              ISNULL(RTRIM(@c_PACKKey), ''),
                              ISNULL(RTRIM(@c_UOM), ''),
                              @c_Status0,
                              @d_Getdate,
                              ISNULL(RTRIM(@c_Lottable01), ''),
                              ISNULL(RTRIM(@c_Lottable02), ''),
                              ISNULL(RTRIM(@c_Lottable03), ''),
                              ISNULL(RTRIM(@d_Lottable04), ''),
                              ISNULL(RTRIM(@d_Lottable05), ''),
                              ISNULL(RTRIM(@c_ToLottable06), ''),
                              ISNULL(RTRIM(@c_ShelfLife), ''),
                              ISNULL(RTRIM(@c_Lottable08), ''),
                              ISNULL(RTRIM(@c_Lottable09), ''),
                              ISNULL(RTRIM(@c_Lottable10), ''),
                              ISNULL(RTRIM(@c_Lottable11), ''),
                              ISNULL(RTRIM(@c_Lottable12), ''),
                              ISNULL(RTRIM(@d_Lottable13), ''),
                              ISNULL(RTRIM(@d_Lottable14), ''),
                              ISNULL(RTRIM(@d_Lottable15), '')
                          );

                         IF @@ERROR = 0
                          BEGIN
                              WHILE @@TRANCOUNT > 0
                                  COMMIT TRAN;

                              IF @b_debug = 1
                                  BEGIN
                                      SELECT 'Insert Records Into Transfer Detail table is Done!';
                                  END;
                          END;
                         ELSE
                          BEGIN
                              SET @n_continue = 3;
                              SET @n_err = 562555;
                              SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) +
                                              ': Insert into TransferDetail Table failed. (msp_ULACalcShelfLife)';
                          END;

                         SET @n_TotalLines = @n_TotalLines + 1;

                         FETCH NEXT FROM CUR_TRANSFERDETAIL INTO  
                             @c_SKU,        @c_Loc,        @c_Lot,        @c_ID,         @n_Qty,        @c_PACKKey,
                             @c_UOM,        @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05, 
                             @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                             @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15;
                     END; -- WHILE @@FETCH_STATUS <> -1
                    CLOSE CUR_TRANSFERDETAIL;
                    DEALLOCATE CUR_TRANSFERDETAIL;
                END; -- IF @n_continue = 1 OR @n_continue = 2
               /*******************************************************/
               /* Insert TransferDetail Records - (End)               */
               /*******************************************************/

               NextRecord:
               FETCH NEXT FROM CUR_TRANSFER INTO @c_Facility, @c_SKU, @d_Lottable04, @c_Lottable07, @d_Lottable13;
          END; -- WHILE @@FETCH_STATUS <> -1
          CLOSE CUR_Transfer;
          DEALLOCATE CUR_TRANSFER;

      END; -- @n_continue = 1 OR @n_continue = 2

    /***********************************************/
    /* Insert Transfer Records (End)               */
    /***********************************************/

/*******************************************************/
/* Finalized Transfer Records - (Start)                */
/*******************************************************/
    IF @n_continue = 1 OR @n_Continue = 2
     BEGIN
         /* declare variables */
         DECLARE CUR_FinalizeTrf CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
             SELECT TransferKey
             FROM #TRANSFER_TRK
             ORDER BY RowID;

         OPEN CUR_FinalizeTrf;

         FETCH NEXT FROM CUR_FinalizeTrf INTO @c_TransferKey;

         WHILE @@FETCH_STATUS <> -1
          BEGIN
              BEGIN TRAN;
              EXEC   [dbo].[ispFinalizeTransfer]
                      @c_Transferkey = @c_TransferKey,
                      @b_Success = @b_Success OUTPUT,
                      @n_err = @n_err OUTPUT,
                      @c_errmsg = @c_errmsg OUTPUT,
                      @c_TransferLineNumber = N'';
              IF @@ERROR = 0
               BEGIN
                   WHILE @@TRANCOUNT > 0
                       COMMIT TRAN;

                   IF @b_debug = 1
                       BEGIN
                           SELECT 'Finalized Transfer. TransferKey=' + @c_TransferKey;
                       END;
               END;
              ELSE
               BEGIN
                   SET @n_continue = 3;
                   SET @n_err = 562556;
                   SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) +
                                   ': Finalized Transfer failed. TransferKey=' + @c_TransferKey + ' (msp_ULACalcShelfLife)';
               END;

              FETCH NEXT FROM CUR_FinalizeTrf INTO @c_TransferKey;
          END;

         CLOSE CUR_FinalizeTrf;
         DEALLOCATE CUR_FinalizeTrf;

     END; -- IF @n_continue = 1 OR @n_continue = 2
/*******************************************************/
/* Finalized Transfer Records - (End)                  */
/*******************************************************/

/***********************************************/
/* Std - Error Handling (Start)                */
/***********************************************/
    QUIT:
    WHILE @@TRANCOUNT < @n_StartTCnt
        BEGIN TRAN;

    IF @n_continue=3  -- Error Occured - Process And Return
     BEGIN
         EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'msp_ULACalcShelfLife';

         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR;
         RETURN;
     END;
    ELSE
     BEGIN
         SELECT @b_success = 1;
         WHILE @@TRANCOUNT > @n_StartTCnt
             BEGIN
                 COMMIT TRAN;
             END;
         RETURN;
     END;
/***********************************************/
/* Std - Error Handling (End)                  */
/***********************************************/
END; -- End Procedure


GO