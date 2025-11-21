SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_ULMAutoRelease                                 */
/* Creation Date: 06-APR-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose:  - IDSMY UNILEVER Auto Release QC Maturity                  */
/*           - To update records for ReceiptDetail.Lottable03 and       */
/*             Generate new Transfer record. (SOS133051)                */
/* Input Parameters:  @c_DataStream    - DataStream                     */
/*                    @c_TargetTable1  - Unilever Control Table         */
/*                    @c_TargetTable2  - Unilever Header Table          */
/*                    @b_debug         - 0                              */
/*                                                                      */
/* Output Parameters: @b_Success       - Success Flag  = 0              */
/*                    @n_err           - Error Code    = 0              */
/*                    @c_errmsg        - Error Message = ''             */
/*                                                                      */
/*                                                                      */
/* Called By:  Scheduler job                                            */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 04-NOV-2009  Vanessa   1.1   SOS#152412 Prevent job fail due to lot  */
/*                              issue cause by manual alloc.(Vanessa01) */
/* 28-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/* 06-JAN-2021  CSCHONG   1.2   WMS-15986 revised logic (CS01)          */
/************************************************************************/

CREATE PROC [dbo].[isp_ULMAutoRelease] (
       @c_StorerKey     NVARCHAR(15)
     , @c_Lottable03    NVARCHAR(18)
     , @c_ToLottable03  NVARCHAR(18)
     --, @c_Facility      NVARCHAR(5)
     , @c_ConfigKey     NVARCHAR(30)
     , @c_Type          NVARCHAR(12)
     , @c_ReasonCode    NVARCHAR(10)
     , @c_Recipients    NVARCHAR(max)
     , @b_debug         int       
     , @b_Success       int       = 0     OUTPUT
     , @n_err           int       = 0     OUTPUT
     , @c_errmsg        NVARCHAR(250) = NULL  OUTPUT
     )
AS 
BEGIN 
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

/*********************************************/
/* Variables Declaration (Start)             */
/*********************************************/
   DECLARE @n_continue  int 
         , @n_StartTCnt int

   SET @n_continue = 1 
   SET @n_StartTCnt = @@TRANCOUNT 
   SET @c_errmsg = ''

   -- General
   DECLARE @c_ExecStatements     NVARCHAR(4000)
      , @c_ExecArguments         NVARCHAR(4000)
      , @d_Getdate               DATETIME
      , @c_Getdate               NVARCHAR(10)
      , @c_Listname1             NVARCHAR(10)
      , @c_Listname2             NVARCHAR(10)
      , @c_HOSTWHCODE            NVARCHAR(10)
      , @n_Check                 int
      , @c_Status0               NVARCHAR(10)
      , @c_Status9               NVARCHAR(10)
      , @c_Profilename           NVARCHAR(10)
      , @c_Subject               NVARCHAR(MAX) 
      , @tableHTML               NVARCHAR(MAX)  
      , @Mailitem_id             int     
      , @c_SValue                NVARCHAR(10)

   -- Header Records
   DECLARE @c_TransferKey        NVARCHAR(10)
      , @c_Facility              NVARCHAR(5)
      , @n_OpenQty               int     
      --, @c_Short                 NVARCHAR(10)         

   -- Detail Records
   DECLARE @c_TransferLineNumber NVARCHAR(5)
      , @c_SKU                   NVARCHAR(20)
      , @c_Loc                   NVARCHAR(10)
      , @c_Lot                   NVARCHAR(10)
      , @c_ID                    NVARCHAR(18)
      , @n_Qty                   int
      , @c_PACKKey               NVARCHAR(10)
      , @c_UOM                   NVARCHAR(10)
      , @c_Lottable01            NVARCHAR(18)
      , @c_Lottable02            NVARCHAR(18)
      , @d_Lottable04            DATETIME
      , @d_Lottable05            DATETIME
      , @c_Lottable06            NVARCHAR(30)
      , @c_Lottable07            NVARCHAR(30)
      , @c_Lottable08            NVARCHAR(30)
      , @c_Lottable09            NVARCHAR(30)
      , @c_Lottable10            NVARCHAR(30)
      , @c_Lottable11            NVARCHAR(30)
      , @c_Lottable12            NVARCHAR(30)
      , @d_Lottable13            DATETIME
      , @d_Lottable14            DATETIME
      , @d_Lottable15            DATETIME

   SET @c_ExecStatements   = ''
   SET @c_ExecArguments    = '' 
   SET @d_Getdate          = GetDate()
   SET @c_GetDate          = RIGHT(ISNULL(RTRIM(CONVERT(CHAR, DATEPART(YEAR, @d_Getdate))),'00'),2)
                             + RIGHT(ISNULL(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, @d_Getdate))),'00'), 2)
                             + RIGHT(ISNULL(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, @d_Getdate))),'00'), 2) 
                             + RIGHT(ISNULL(RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, @d_Getdate))),'00'), 2) 
                             + RIGHT(ISNULL(RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, @d_Getdate))),'00'), 2)
                             --+ RIGHT(ISNULL(RTRIM('0' + CONVERT(CHAR, DATEPART(SECOND, @d_Getdate))),'00'), 2) CustomerReferenceNo only allow NVARCHAR(10)
   SET @c_Listname1        = 'TRANTYPE'
   SET @c_Listname2        = 'TRNReason'
   SET @c_HOSTWHCODE       = 'M001'
   SET @n_Check            = 0 
   SET @c_Status0          = '0' 
   SET @c_Status9          = '9' 
   SET @c_Profilename      = 'IDSMY-IT'
   SET @c_Subject          = '[Alert] Auto QC Maturity Release Fail' -- (Vanessa01)
/*********************************************/
/* Variables Declaration (End)               */
/*********************************************/

/*********************************************/
/* Main Validation (Start)                   */
/*********************************************/
   IF ISNULL(RTRIM(@c_StorerKey), '') = '' OR
      ISNULL(RTRIM(@c_Lottable03), '') = '' OR
      ISNULL(RTRIM(@c_ToLottable03), '') = '' OR
      --ISNULL(RTRIM(@c_Facility), '') = '' OR
      ISNULL(RTRIM(@c_ConfigKey), '') = '' OR
      ISNULL(RTRIM(@c_Type), '') = '' OR
      ISNULL(RTRIM(@c_ReasonCode), '') = '' OR
      ISNULL(RTRIM(@c_Recipients), '') = ''
   BEGIN
      SET @n_continue = 3
      SET @n_err = 68000
      SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) + 
                      ': Main Parameters not proper setup. StorerKey:' + ISNULL(RTRIM(@c_StorerKey), '') + 
                      ', Lottable03:' + ISNULL(RTRIM(@c_Lottable03), '') + ', ToLottable03:' + ISNULL(RTRIM(@c_ToLottable03), '') + 
                      --', Facility:' + ISNULL(RTRIM(@c_Facility), '') + 
                      ', ConfigKey:' + ISNULL(RTRIM(@c_ConfigKey), '') + 
                      ', Type:' + ISNULL(RTRIM(@c_Type), '') + ', ReasonCode:' + ISNULL(RTRIM(@c_ReasonCode), '') + 
                      ', @c_Recipients:' + ISNULL(RTRIM(@c_Recipients), '') + ' (isp_ULMAutoRelease)'  
      GOTO QUIT
   END 

   SELECT @c_SValue = SVALUE FROM STORERCONFIG WITH (NOLOCK)
   WHERE STORERKEY = ISNULL(RTRIM(@c_StorerKey), '')
   AND CONFIGKEY = ISNULL(RTRIM(@c_ConfigKey), '')

   IF ISNULL(RTRIM(@c_SValue), '') <> '1'
   BEGIN
      SET @n_continue = 3
      SET @n_err = 68001
      SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) + 
                      ': STORERCONFIG.SVALUE Setup not exists(For Allow QC Maturity Auto Release). STORERKEY:' + ISNULL(RTRIM(@c_StorerKey), '') + ', CONFIGKEY:' + ISNULL(RTRIM(@c_ConfigKey), '') + ' (isp_ULMAutoRelease)'  
      GOTO QUIT
   END

   SELECT @n_Check = Count(1) FROM CODELKUP WITH (NOLOCK)
   WHERE Listname = ISNULL(RTRIM(@c_Listname1), '')
   AND Code = ISNULL(RTRIM(@c_Type), '')

   IF @n_Check <> 1 
   BEGIN
      SET @n_continue = 3
      SET @n_err = 68002
      SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) + 
                      ': CODELKUP Setup not exists(For Type). Listname:' + ISNULL(RTRIM(@c_Listname1), '') + ', Code:' + ISNULL(RTRIM(@c_Type), '') + ' (isp_ULMAutoRelease)'  
      GOTO QUIT
   END

   SET @n_Check = 0
   SELECT --@c_Short = Short,
          @n_Check = Count(1) 
   FROM CODELKUP WITH (NOLOCK)
   WHERE Listname = ISNULL(RTRIM(@c_Listname2), '')
   AND Code = ISNULL(RTRIM(@c_ReasonCode), '')
   --Group by Short
   
   IF @n_Check <> 1
   BEGIN
      SET @n_continue = 3
      SET @n_err = 68003
      SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) + 
                      ': CODELKUP.Short Setup not exists(For Reason Code). Listname:' + ISNULL(RTRIM(@c_Listname2), '') + ', Code:' + ISNULL(RTRIM(@c_ReasonCode), '') + ' (isp_ULMAutoRelease)'  
      GOTO QUIT
   END
/*********************************************/
/* Main Validation (END)                     */
/*********************************************/

/*******************************************************/
/* Insert Transfer Records - (Start)                   */
/*******************************************************/
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @c_Facility   = ''
      SET @n_OpenQty    = 0

      -- Retrieve related info from inventory table into a cursor
      DECLARE C_Transfer CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT LOC.Facility, SUM(LOTxLOCxID.Qty)
      FROM LOTxLOCxID WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON ( LOTxLOCxID.Loc = LOC.LOC)
      JOIN LOTAttribute WITH (NOLOCK, INDEX(PKLOTAttribute) ) ON (LOTxLOCxID.Lot = LOTAttribute.LOT)
      JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKU.StorerKey 
                             AND LOTxLOCxID.SKU = SKU.SKU
                             AND ISNUMERIC(ISNULL(SKU.Busr10, 0)) = 1)
      JOIN PACK WITH (NOLOCK) ON (SKU.PACKKey = PACK.PACKKey)
      JOIN LOT WITH (NOLOCK) ON ( LOTxLOCxID.LOT = LOT.LOT) -- (Vanessa01)
      WHERE LOTxLOCxID.StorerKey = ISNULL(RTRIM(@c_StorerKey), '')
      --AND LOC.Facility = ISNULL(RTRIM(@c_Facility), '')
      AND LOTxLOCxID.Qty > 0 
      AND LOC.HOSTWHCODE = ISNULL(RTRIM(@c_HOSTWHCODE), '') --20-AUG-09: Data Selection for LOC.HOSTWHCODE='M001'. (Vanessa)
      AND LOTAttribute.Lottable03 = ISNULL(RTRIM(@c_Lottable03), '')
      AND LOT.QtyPreAllocated = 0 -- (Vanessa01)
      AND LOT.QtyAllocated =0     -- (Vanessa01)
      AND LOT.QtyPicked = 0       -- (Vanessa01)
      --AND DATEDIFF(Day, CONVERT(varchar(8), LOTAttribute.Lottable05, 112), CONVERT(varchar(8), GetDate(), 112))      --CS01
      AND DATEDIFF(Day,CONVERT(DATETIME, SUBSTRING(LOTAttribute.Lottable01,5,4) + SUBSTRING(LOTAttribute.Lottable01,3,2) + 
                   LEFT(LOTAttribute.Lottable01,2)), CONVERT(varchar(8), GetDate(), 112))                              --CS01
          >= CONVERT(INT, SKU.Busr10) 
      GROUP BY LOC.Facility

      OPEN C_Transfer   

      FETCH NEXT FROM C_Transfer INTO @c_Facility, @n_OpenQty

      WHILE @@FETCH_STATUS <> -1 
      BEGIN    

         IF ISNULL(@n_OpenQty, 0) > 0 
         BEGIN
            BEGIN TRAN 
            -- get next receipt key
            SELECT @b_success = 0
            EXECUTE   nspg_getkey
                     'TRANSFER'
                     , 10
                     , @c_TransferKey OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

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
                                     ISNULL(RTRIM(@c_Type), ''), 
                                     ISNULL(RTRIM(@n_OpenQty), 0),
                                     @c_Status0,
                                     @d_Getdate,
                                     ISNULL(RTRIM(@c_ReasonCode), ''),
                                     ISNULL(RTRIM(@c_Getdate), ''),
                                     ISNULL(RTRIM(@c_Facility), ''),
                                     ISNULL(RTRIM(@c_Facility), ''))               

               IF @@ERROR = 0 
               BEGIN
                  WHILE @@TRANCOUNT > 0
                     COMMIT TRAN 

                  IF @b_debug = 1
                  BEGIN
                     SELECT 'Insert Records Into Transfer table is Done!'
                  END
               END
               ELSE
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 68004
                  SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) + 
                                  ': Insert into Transfer Table failed. (isp_ULMAutoRelease)'  
                  GOTO QUIT
               END 
            END -- @b_success = 1
            ELSE
            BEGIN
               SET @n_continue = 3
               SET @n_err = 68005 
               SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) + 
                               ': Generate Transfer Key Failed. (isp_ULMAutoRelease)'  
               GOTO QUIT
            END -- @b_success = 1
         END -- ISNULL(@n_OpenQty, 0) > 0 
         ELSE
         BEGIN
            SET @n_continue = 3
            SET @n_err = 68006 
            SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) + 
                            ': Transfer Open Qty cant be null! (isp_ULMAutoRelease)'  
            GOTO QUIT
         END 

         /***********************************************/
         /* Insert TransferDetail (Start)               */
         /***********************************************/
         IF @n_continue = 1 OR @n_Continue = 2   
         BEGIN
            SET @c_TransferLineNumber  = ''
            SET @c_SKU                 = ''
            SET @c_Loc                 = ''
            SET @c_Lot                 = ''
            SET @c_ID                  = ''
            SET @n_Qty                 = 0
            SET @c_PACKKey             = ''
            SET @c_UOM                 = ''
            SET @c_Lottable01          = ''
            SET @c_Lottable02          = ''
            SET @d_Lottable04          = ''
            SET @d_Lottable05          = ''
            SET @c_Lottable06          = ''
            SET @c_Lottable07          = ''
            SET @c_Lottable08          = ''
            SET @c_Lottable09          = ''
            SET @c_Lottable10          = ''
            SET @c_Lottable11          = ''
            SET @c_Lottable12          = ''
            SET @d_Lottable13          = ''
            SET @d_Lottable14          = ''
            SET @d_Lottable15          = ''

            -- Retrieve related info from inventory table into a cursor
            DECLARE C_TransferDetail CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT LOTxLOCxID.SKU, 
                   LOTxLOCxID.Loc,
                   LOTxLOCxID.Lot,
                   LOTxLOCxID.ID,
                   LOTxLOCxID.Qty,
                   SKU.PACKKey,  
                   PACK.PackUOM3,
                   LOTAttribute.Lottable01,
                   LOTAttribute.Lottable02,
                   LOTAttribute.Lottable04,
                   LOTAttribute.Lottable05,
                   LOTAttribute.Lottable06,
                   LOTAttribute.Lottable07,
                   LOTAttribute.Lottable08,
                   LOTAttribute.Lottable09,
                   LOTAttribute.Lottable10,
                   LOTAttribute.Lottable11,
                   LOTAttribute.Lottable12,
                   LOTAttribute.Lottable13,
                   LOTAttribute.Lottable14,
                   LOTAttribute.Lottable15
            FROM LOTxLOCxID WITH (NOLOCK)
            JOIN LOC WITH (NOLOCK) ON ( LOTxLOCxID.Loc = LOC.LOC)
            JOIN LOTAttribute WITH (NOLOCK, INDEX(PKLOTAttribute) ) ON (LOTxLOCxID.Lot = LOTAttribute.LOT)
            JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKU.StorerKey 
                                   AND LOTxLOCxID.SKU = SKU.SKU
                                   AND ISNUMERIC(ISNULL(SKU.Busr10, 0)) = 1)
            JOIN PACK WITH (NOLOCK) ON (SKU.PACKKey = PACK.PACKKey)
            JOIN LOT WITH (NOLOCK) ON ( LOTxLOCxID.LOT = LOT.LOT) -- (Vanessa01)
            WHERE LOTxLOCxID.StorerKey = ISNULL(RTRIM(@c_StorerKey), '')
            AND LOTxLOCxID.Qty > 0 
            AND LOC.Facility = ISNULL(RTRIM(@c_Facility), '')
            AND LOC.HOSTWHCODE = ISNULL(RTRIM(@c_HOSTWHCODE), '')  --20-AUG-09: Data Selection for LOC.HOSTWHCODE='M001'. (Vanessa)
            AND LOTAttribute.Lottable03 = ISNULL(RTRIM(@c_Lottable03), '')
            AND LOT.QtyPreAllocated = 0 -- (Vanessa01)
            AND LOT.QtyAllocated =0     -- (Vanessa01)
            AND LOT.QtyPicked = 0       -- (Vanessa01)
            --AND DATEDIFF(Day, CONVERT(varchar(8), LOTAttribute.Lottable05, 112), CONVERT(varchar(8), GetDate(), 112))        --CS01
             AND DATEDIFF(Day,CONVERT(DATETIME, SUBSTRING(LOTAttribute.Lottable01,5,4) + SUBSTRING(LOTAttribute.Lottable01,3,2) + 
                   LEFT(LOTAttribute.Lottable01,2)), CONVERT(varchar(8), GetDate(), 112))                              --CS01
                >= CONVERT(INT, SKU.Busr10) 

            OPEN C_TransferDetail   

            FETCH NEXT FROM C_TransferDetail INTO  @c_SKU,        @c_Loc,        @c_Lot,        @c_ID,         @n_Qty,      @c_PACKKey,  
                                                   @c_UOM,        @c_Lottable01, @c_Lottable02, @d_Lottable04, @d_Lottable05,
                                                   @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                                   @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
            WHILE @@FETCH_STATUS <> -1 
            BEGIN    

               SELECT @c_TransferLineNumber = MAX(TransferLineNumber) 
               FROM TransferDetail WITH (NOLOCK)
               WHERE TransferKey = @c_TransferKey

               SET @c_TransferLineNumber = RIGHT('0000' + RTRIM(CAST(CAST(ISNULL(@c_TransferLineNumber,0) AS int) + 1 AS NVARCHAR(5))),5)

               BEGIN TRAN 
               INSERT INTO TransferDetail (TransferKey,   
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
                                           ToLottable15)
                                   VALUES (@c_TransferKey, 
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
                                           --ISNULL(RTRIM(@c_Lot), ''), 
                                           ISNULL(RTRIM(@c_ID), ''), 
                                           ISNULL(RTRIM(@n_Qty), 0), 
                                           ISNULL(RTRIM(@c_PACKKey), ''), 
                                           ISNULL(RTRIM(@c_UOM), ''), 
                                           @c_Status0,
                                           @d_Getdate,
                                           ISNULL(RTRIM(@c_Lottable01), ''), 
                                           ISNULL(RTRIM(@c_Lottable02), ''), 
                                           ISNULL(RTRIM(@c_ToLottable03), ''), 
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
                                           ISNULL(RTRIM(@d_Lottable15), '')) 

               IF @@ERROR = 0 
               BEGIN
                  WHILE @@TRANCOUNT > 0
                     COMMIT TRAN 

                  IF @b_debug = 1
                  BEGIN
                     SELECT 'Insert Records Into Transfer Detail table is Done!'
                  END
               END
               ELSE
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 68007
                        SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) + 
                                        ': Insert into TransferDetail Table failed. (isp_ULMAutoRelease)'  
               END 

               SET @c_TransferLineNumber  = ''
               SET @c_SKU                 = ''
               SET @c_Loc                 = ''
               SET @c_Lot                 = ''
               SET @c_ID                  = ''
               SET @n_Qty                 = 0
               SET @c_PACKKey             = ''
               SET @c_UOM                 = ''
               SET @c_Lottable01          = ''
               SET @c_Lottable02          = ''
               SET @d_Lottable04          = ''
               SET @d_Lottable05          = ''
               SET @c_Lottable06          = ''
               SET @c_Lottable07          = ''
               SET @c_Lottable08          = ''
               SET @c_Lottable09          = ''
               SET @c_Lottable10          = ''
               SET @c_Lottable11          = ''
               SET @c_Lottable12          = ''
               SET @d_Lottable13          = ''
               SET @d_Lottable14          = ''
               SET @d_Lottable15          = ''

               FETCH NEXT FROM C_TransferDetail INTO  @c_SKU,        @c_Loc,        @c_Lot,        @c_ID,         @n_Qty,      @c_PACKKey,  
                                                      @c_UOM,        @c_Lottable01, @c_Lottable02, @d_Lottable04, @d_Lottable05,
                                                      @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                                                      @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
            END -- WHILE @@FETCH_STATUS <> -1 
            CLOSE C_TransferDetail
            DEALLOCATE C_TransferDetail 
         END -- IF @n_continue = 1 OR @n_continue = 2
         /*******************************************************/
         /* Insert TransferDetail Records - (End)               */
         /*******************************************************/

         /*******************************************************/
         /* Finalized Transfer Records - (Start)                */
         /*******************************************************/
         IF @n_continue = 1 OR @n_Continue = 2   
         BEGIN
            BEGIN TRAN 
            UPDATE TransferDetail WITH (ROWLOCK)
            SET Status = @c_Status9
            WHERE TransferKey = @c_TransferKey

       IF @@ERROR = 0 
            BEGIN
               WHILE @@TRANCOUNT > 0
                  COMMIT TRAN 

               IF @b_debug = 1
               BEGIN
                  SELECT 'Finalized TransferDetail Records. TransferKey=' + @c_TransferKey
               END
            END
            ELSE
            BEGIN
               SET @n_continue = 3
               SET @n_err = 68008
                     SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) + 
                                     ': Finalized TransferDetail Records failed. TransferKey=' + @c_TransferKey + ' (isp_ULMAutoRelease)'  
            END 

            BEGIN TRAN 
            UPDATE Transfer WITH (ROWLOCK)
            SET Status = @c_Status9
            WHERE TransferKey = @c_TransferKey

            IF @@ERROR = 0 
            BEGIN
               WHILE @@TRANCOUNT > 0
                  COMMIT TRAN 

               IF @b_debug = 1
               BEGIN
                  SELECT 'Finalized Transfer Records. TransferKey=' + @c_TransferKey
               END
            END
            ELSE
            BEGIN
               SET @n_continue = 3
               SET @n_err = 68009
                     SET @c_errmsg = 'NSQL' + CONVERT(varchar(5),ISNULL(@n_err,0)) + 
                                     ': Finalized Transfer Records failed. TransferKey=' + @c_TransferKey + ' (isp_ULMAutoRelease)'  
            END 
         END -- IF @n_continue = 1 OR @n_continue = 2
         /*******************************************************/
         /* Finalized Transfer Records - (End)                  */
         /*******************************************************/
         NextRecord:
         SET @c_Facility   = ''
         SET @n_OpenQty    = 0
         FETCH NEXT FROM C_Transfer INTO @c_Facility, @n_OpenQty
      END -- WHILE @@FETCH_STATUS <> -1 
      CLOSE C_Transfer
      DEALLOCATE C_Transfer 

      IF @n_continue = 1 OR @n_Continue = 2   
      BEGIN
         SELECT LOTxLOCxID.SKU, 
                LOTxLOCxID.Loc,
                LOTxLOCxID.Lot,
                LOTxLOCxID.ID,
                LOTxLOCxID.Qty,
                LOT.QtyPreAllocated,
                LOT.QtyAllocated, 
                LOT.QtyPicked
         INTO #TEMPLotTransfer
         FROM LOTxLOCxID WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON ( LOTxLOCxID.Loc = LOC.LOC)
         JOIN LOTAttribute WITH (NOLOCK, INDEX(PKLOTAttribute) ) ON (LOTxLOCxID.Lot = LOTAttribute.LOT)
         JOIN SKU WITH (NOLOCK) ON (LOTxLOCxID.StorerKey = SKU.StorerKey 
                                AND LOTxLOCxID.SKU = SKU.SKU
                                AND ISNUMERIC(ISNULL(SKU.Busr10, 0)) = 1)
         JOIN LOT WITH (NOLOCK) ON ( LOTxLOCxID.LOT = LOT.LOT) -- (Vanessa01)
         WHERE LOTxLOCxID.StorerKey = ISNULL(RTRIM(@c_StorerKey), '')
         AND LOTxLOCxID.Qty > 0 
         AND LOC.HOSTWHCODE = ISNULL(RTRIM(@c_HOSTWHCODE), '')  --20-AUG-09: Data Selection for LOC.HOSTWHCODE='M001'. (Vanessa)
         AND LOTAttribute.Lottable03 = ISNULL(RTRIM(@c_Lottable03), '')
         AND (LOT.QtyPreAllocated > 0 OR LOT.QtyAllocated > 0 OR LOT.QtyPicked > 0) -- (Vanessa01)
         --AND DATEDIFF(Day, CONVERT(varchar(8), LOTAttribute.Lottable05, 112), CONVERT(varchar(8), GetDate(), 112))     --CS01
          AND DATEDIFF(Day,CONVERT(DATETIME, SUBSTRING(LOTAttribute.Lottable01,5,4) + SUBSTRING(LOTAttribute.Lottable01,3,2) + 
                   LEFT(LOTAttribute.Lottable01,2)), CONVERT(varchar(8), GetDate(), 112))                              --CS01 
             >= CONVERT(INT, SKU.Busr10) 

         IF @@ROWCOUNT > 0
         BEGIN
            SET @tableHTML =     
                N'<H4>List of Lot Fail for Transfer </H4>' +    
                N'<H5>Please take action as QC Maturity Failed due to QI stocks are allocated/picked for:</H5>' +    
                N'<table border="1">' +    
                N'<tr><th>SKU</th>' +    
                N'<th>Loc</th><th>Lot</th><th>ID</th><th>Qty</th>' +    
                N'<th>QtyPreAllocated</th><th>QtyAllocated</th><th>QtyPicked</th></tr>' +    
                CAST ( ( SELECT td = SKU, '',     
                                td = Loc, '',   
                                td = Lot, '',   
                                td = ID, '',   
                                td = Qty, '',   
                                td = QtyPreAllocated, '',   
                                td = QtyAllocated, '', 
                                td = QtyPicked, ''
                  FROM #TEMPLotTransfer 
                  FOR XML PATH('tr'), TYPE     
                ) AS NVARCHAR(MAX) ) +    
                N'</table>' +     
                N'<H4>From WMS BEJ - IDSMY_Unilever_ULMAutoRelease JOB.</H4>' ;    

            EXEC msdb.dbo.sp_send_dbmail     
                @recipients=@c_Recipients,    
                @subject = @c_Subject,    
                @body = @tableHTML,    
                @body_format = 'HTML',    
                @mailitem_id = @Mailitem_id OUTPUT;    
          
            SELECT @Mailitem_id
         END
         DROP Table #TEMPLotTransfer 
      END

   END -- @n_continue = 1 OR @n_continue = 2 
/***********************************************/
/* Insert Transfer Records (End)               */
/***********************************************/

/***********************************************/
/* Std - Error Handling (Start)                */
/***********************************************/
QUIT:

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN 

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  

      EXEC msdb.dbo.sp_send_dbmail
          @profile_name = @c_Profilename,
          @recipients   = @c_Recipients,
          @body         = @c_errmsg,
          @subject      = @c_Subject

      SELECT @b_success = 0  
      IF @@TRANCOUNT > @n_StartTCnt  
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ULMAutoRelease' 

      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
/***********************************************/
/* Std - Error Handling (End)                  */
/***********************************************/
END -- End Procedure 


GO