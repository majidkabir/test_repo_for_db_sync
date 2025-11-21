SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_Combine_Load                                   */
/* Creation Date: 23-Aug-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: Created based on SOS55048 - to combine 2 loads              */
/*                                                                      */
/* Called By: PB object - nep_n_cst_policy_combine_load (w_combine_load)*/
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 21-Sep-2006  MaryVong   Reset FromLoad with FinalizeFlag = 'N',      */
/*                         to avoid blocking in ntrLoadPlanDelete       */
/*                         (if configkey 'FinalizeLP' is turned on)     */
/* 14-Jan-2016  Leong      SOS# 361123 - Add DataMartDELLOG.            */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_Combine_Load]
     @c_FromLoadKey NVARCHAR(10)
   , @c_ToLoadKey   NVARCHAR(10)
   , @b_Success     INT           OUTPUT
   , @n_Err         INT           OUTPUT
   , @c_ErrMsg      NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @n_Starttcnt INT,
      @n_Continue  INT,
      @b_Debug     INT

   DECLARE
      @c_FromFacility      NVARCHAR(5),
      @c_ToFacility        NVARCHAR(5),
      @c_FromLoadLineNo    NVARCHAR(5),
      @n_MaxToLoadLineNo   INT,
      @c_MaxToLoadLineNo   NVARCHAR(5),
      @c_NewToLoadLineNo   NVARCHAR(5)

   DECLARE
      @c_OrderKey     NVARCHAR(10),
      @n_OrderCnt     INT,
      @n_CustCnt      INT,
      @n_PalletCnt    INT,
      @n_CaseCnt      INT,
      @n_Weight       FLOAT,
      @n_Cube         FLOAT,
      @n_TotPalletCnt INT,
      @n_TotCaseCnt   INT,
      @n_TotWeight    FLOAT,
      @n_TotCube      FLOAT
    , @c_Authority    NVARCHAR(1)

   SELECT
      @b_Success = 0,
      @n_Continue = 1,
      @n_Starttcnt = @@TRANCOUNT,
      @b_Debug = 0

   -- Validate FromLoad and ToLoad
   IF NOT EXISTS (SELECT 1 FROM LOADPLAN (NOLOCK) WHERE LoadKey = @c_FromLoadKey)
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65001
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': LoadKey Not Found ' + dbo.fnc_RTrim(@c_FromLoadKey) + ' (isp_Combine_Load)'
      GOTO QUIT
   END

   IF EXISTS (SELECT 1 FROM LOADPLAN (NOLOCK) WHERE LoadKey = @c_FromLoadKey AND Status = '9')
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65002
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Cannot combine with Shipped Load ' + dbo.fnc_RTrim(@c_FromLoadKey) + ' (isp_Combine_Load)'
      GOTO QUIT
   END

   IF EXISTS (SELECT 1 FROM LOADPLAN (NOLOCK) WHERE LoadKey = @c_ToLoadKey AND Status = '9')
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65003
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Cannot combine with Shipped Load ' + dbo.fnc_RTrim(@c_ToLoadKey) + ' (isp_Combine_Load)'
      GOTO QUIT
   END

   -- Verify facility
   SELECT
      @c_FromFacility = '',
      @c_ToFacility = ''

   SELECT @c_FromFacility = Facility
   FROM LOADPLAN (NOLOCK)
   WHERE LoadKey = @c_FromLoadKey

   SELECT @c_ToFacility = Facility
   FROM LOADPLAN (NOLOCK)
   WHERE LoadKey = @c_ToLoadKey

   IF @b_Debug = 1
      SELECT @c_FromFacility '@c_FromFacility', @c_ToFacility '@c_ToFacility'

   IF @c_FromFacility <> @c_ToFacility
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65004
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Cannot combine loads from different facility. (isp_Combine_Load)'
      GOTO QUIT
   END

   IF @n_Continue = 1 OR @n_Continue = 2 -- SOS# 361123
   BEGIN
      SET @c_Authority = '0'
      SET @b_Success = 0
      EXEC nspGetRight NULL             -- Facility
                     , NULL             -- StorerKey
                     , NULL             -- Sku
                     , 'DataMartDELLOG' -- ConfigKey
                     , @b_Success   OUTPUT
                     , @c_Authority OUTPUT
                     , @n_Err       OUTPUT
                     , @c_ErrMsg    OUTPUT
      
      IF @b_Success <> 1
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 65011
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': ' + ISNULL(RTRIM(@c_ErrMsg),'') + ' (isp_Combine_Load).'
      END
   END

   IF (@n_Continue = 1 OR @n_Continue = 2) -- Perform Updates
   BEGIN
      BEGIN TRAN

      /* ----------------------- Update LoadPlanDetail: from FromLoad to ToLoad -------------------------*/
      SELECT
         @c_FromLoadLineNo       = '',
         @n_MaxToLoadLineNo      = 0,
         @c_MaxToLoadLineNo      = '',
         @c_NewToLoadLineNo      = ''

      -- Get maximum detail line number of ToLoad
      SELECT @c_MaxToLoadLineNo = MAX(LoadLineNumber)
      FROM LOADPLANDETAIL (NOLOCK)
      WHERE LoadKey = @c_ToLoadKey

      SELECT @n_MaxToLoadLineNo = CONVERT(INT, @c_MaxToLoadLineNo)

      IF @b_Debug = 1
         SELECT @c_MaxToLoadLineNo '@c_MaxToLoadLineNo', @n_MaxToLoadLineNo '@n_MaxToLoadLineNo'

      -- Create a memory table
      DECLARE @tLoadDet TABLE
      (
        [ID] INT IDENTITY(1,1),
        LoadKey NVARCHAR(10) NOT NULL,
        LoadLineNumber NVARCHAR(5) NOT NULL,
        PRIMARY KEY CLUSTERED (LoadKey, LoadLineNumber)
      )

      INSERT INTO @tLoadDet (LoadKey, LoadLineNumber)
      SELECT LoadKey, LoadLineNumber
      FROM LOADPLANDETAIL (NOLOCK)
      WHERE LoadKey = @c_FromLoadKey

      -- Loop thru each FromLoad detail lines, update detail lines
      DECLARE LOADDET_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LoadLineNumber
         FROM   @tLoadDet
         ORDER BY LoadLineNumber

      OPEN LOADDET_CUR

      FETCH NEXT FROM LOADDET_CUR INTO @c_FromLoadLineNo

      WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         -- Increase LineNo by 1
         SELECT @n_MaxToLoadLineNo = @n_MaxToLoadLineNo + 1
         SELECT @c_NewToLoadLineNo = RIGHT(REPLICATE('0', 5) + dbo.fnc_RTrim(CONVERT(CHAR(5), @n_MaxToLoadLineNo)), 5)

         IF @b_Debug = 1
            SELECT @c_NewToLoadLineNo '@c_NewToLoadLineNo'

         UPDATE LOADPLANDETAIL WITH (ROWLOCK)
         SET   LoadKey        = @c_ToLoadKey,
               LoadLineNumber = @c_NewToLoadLineNo,
               EditWho        = SUSER_SNAME(),
               EditDate       = GETDATE(),
               TrafficCop     = NULL
         WHERE LoadKey        = @c_FromLoadKey
         AND   LoadLineNumber = @c_FromLoadLineNo

         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 65005
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Update Failed On Table LOADPLANDETAIL. (isp_Combine_Load)'
         END

         IF @c_Authority = '1' AND (@n_Continue = 1 OR @n_Continue = 2) -- SOS# 361123
         BEGIN
            INSERT INTO dbo.LoadPlanDetail_DELLOG ( LoadKey, LoadLineNumber )
            VALUES ( @c_FromLoadKey, @c_FromLoadLineNo )
      
            SELECT @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @n_Err = 65012
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Insert Log Failed (isp_Combine_Load).' + ' (' + 'SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ')'
            END
         END

         FETCH NEXT FROM LOADDET_CUR INTO @c_FromLoadLineNo
      END

      CLOSE LOADDET_CUR
      DEALLOCATE LOADDET_CUR
      /* ------------------- End of Update LoadPlanDetail: from FromLoad to ToLoad ----------------------*/

      IF (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
      /* ------------ Update LoadPlan (header) fields for ToLoad (not go thru trigger) ------------------*/
         SELECT
            @c_OrderKey     = '',
            @n_OrderCnt     = 0,
            @n_CustCnt      = 0,
            @n_PalletCnt    = 0,
            @n_CaseCnt      = 0,
            @n_Weight       = 0,
            @n_Cube         = 0,
            @n_TotPalletCnt = 0,
            @n_TotCaseCnt   = 0,
            @n_TotWeight    = 0,
            @n_TotCube      = 0

         -- Create a memory table
         DECLARE @tLoad TABLE
         (
           [ID] INT IDENTITY(1,1),
           LoadKey NVARCHAR(10) NOT NULL,
           LoadLineNumber NVARCHAR(5) NOT NULL,
           OrderKey NVARCHAR(10) NOT NULL,
           ConsigneeKey NVARCHAR(15) NULL,
           Weight FLOAT NULL DEFAULT (0),
           [Cube] FLOAT NULL DEFAULT (0),
           PRIMARY KEY CLUSTERED (LoadKey, LoadLineNumber)
         )

         INSERT INTO @tLoad (LoadKey, LoadLineNumber, OrderKey, ConsigneeKey, Weight, [Cube])
         SELECT LoadKey, LoadLineNumber, OrderKey, ConsigneeKey, Weight, [Cube]
         FROM LOADPLANDETAIL (NOLOCK)
         WHERE LoadKey = @c_ToLoadKey
         ORDER BY LoadKey, LoadLineNumber

         -- Get OrderCnt and CustCnt
         SELECT
            @n_OrderCnt = ISNULL( COUNT(DISTINCT OrderKey), 0),
            @n_CustCnt  = ISNULL( COUNT(DISTINCT ConsigneeKey), 0)
         FROM  @tLoad
         WHERE LoadKey = @c_ToLoadKey

         DECLARE LOAD_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT OrderKey, Weight, [Cube]
         FROM @tLoad
         WHERE LoadKey = @c_ToLoadKey
         ORDER BY LoadKey, LoadLineNumber

         OPEN LOAD_CUR

         FETCH NEXT FROM LOAD_CUR INTO @c_OrderKey, @n_Weight, @n_Cube

         WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
         BEGIN
            SELECT
               @n_PalletCnt = CONVERT(INT, SUM(CASE WHEN PACK.Pallet = 0 THEN 0 ELSE (OD.OpenQty / PACK.Pallet) END)),
               @n_CaseCnt = CONVERT(INT, SUM(CASE WHEN PACK.CaseCnt = 0 THEN 0 ELSE (OD.OpenQty / PACK.CaseCnt) END))
            FROM ORDERDETAIL OD (NOLOCK)
            INNER JOIN SKU SKU (NOLOCK) ON (OD.SKU = SKU.SKU AND OD.Storerkey = SKU.Storerkey)
            INNER JOIN PACK PACK (NOLOCK) ON (SKU.PacKkey = PACK.PackKey)
            WHERE OD.OrderKey = @c_OrderKey

            SELECT @n_TotPalletCnt = @n_TotPalletCnt + ISNULL(@n_PalletCnt, 0)
            SELECT @n_TotCaseCnt = @n_TotCaseCnt + ISNULL(@n_CaseCnt, 0)
            SELECT @n_TotWeight = @n_TotWeight + ISNULL(@n_Weight, 0)
            SELECT @n_TotCube = @n_TotCube + ISNULL(@n_Cube, 0)

            FETCH NEXT FROM LOAD_CUR INTO @c_OrderKey, @n_Weight, @n_Cube
         END -- WHILE

         CLOSE LOAD_CUR
         DEALLOCATE LOAD_CUR

         UPDATE LOADPLAN WITH (ROWLOCK)
         SET OrderCnt   = @n_OrderCnt,
             CustCnt    = @n_CustCnt,
             PalletCnt  = @n_TotPalletCnt,
             CaseCnt    = @n_TotCaseCnt,
             Weight     = @n_TotWeight,
             Cube       = @n_TotCube,
             EditWho    = SUSER_SNAME(),
             EditDate   = GETDATE(),
             TrafficCop = NULL
         WHERE LoadKey  = @c_ToLoadKey

         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 65006
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Update Failed On Table LOADPLAN. (isp_Combine_Load)'
         END
      END
      /* --------- End of Update LoadPlan (header) fields for ToLoad (not go thru trigger) --------------*/


      IF (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
      /* ---------- Update Orders and OrderDetail, Update and Delete FromLoad from LoadPlan -------------*/
         -- Create a memory table
         DECLARE @tOrder TABLE
         (
            [ID] INT IDENTITY(1,1),
            OrderKey NVARCHAR(10) NOT NULL,
            OrderLineNumber NVARCHAR(5) NOT NULL,
            PRIMARY KEY CLUSTERED (OrderKey, OrderLineNumber)
         )

         INSERT INTO @tOrder (OrderKey, OrderLineNumber)
         SELECT OrderKey, OrderLineNumber
         FROM ORDERDETAIL (NOLOCK)
         WHERE LoadKey = @c_FromLoadKey

         -- Update Orders
         UPDATE ORDERS WITH (ROWLOCK)
         SET LoadKey    = @c_ToLoadKey,
             EditWho    = SUSER_SNAME(),
             EditDate   = GETDATE(),
             TrafficCop = NULL
         FROM @tOrder T
         INNER JOIN ORDERS OH ON (T.OrderKey = OH.OrderKey)

         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 65007
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Update Failed On Table ORDERS. (isp_Combine_Load)'
         END

         -- Update OrderDetail
         UPDATE ORDERDETAIL WITH (ROWLOCK)
         SET LoadKey    = @c_ToLoadKey,
             EditWho    = SUSER_SNAME(),
             EditDate   = GETDATE(),
             TrafficCop = NULL
         FROM @tOrder T
            INNER JOIN ORDERDETAIL OD ON (T.OrderKey = OD.OrderKey AND T.OrderLineNumber = OD.OrderLineNumber)

         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 65008
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Update Failed On Table ORDERDETAIL. (isp_Combine_Load)'
         END

         -- Reset FromLoad with FinalizeFlag = 'N'
         -- To avoid blocking in ntrLoadPlanDelete (if configkey 'FinalizeLP' is turned on)
         UPDATE LOADPLAN WITH (ROWLOCK)
         SET FinalizeFlag = 'N',
             TrafficCop = NULL
         WHERE LoadKey = @c_FromLoadKey

         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 65009
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Update Failed On Table LOADPLAN. (isp_Combine_Load)'
         END

         -- Delete FromLoad
         DELETE LOADPLAN WHERE LoadKey = @c_FromLoadKey

         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 65010
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Delete Failed On Table LOADPLAN. (isp_Combine_Load)'
         END
      END
      /* ------- End of Update Orders and OrderDetail, Update and Delete FromLoad from LoadPlan ---------*/

   END -- @n_Continue = 1 OR @n_Continue = 2 -- Perform Updates

   QUIT:
   -- Error Occured - Process And Return
   IF @n_Continue = 3
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_Starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_Starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_LogError @n_Err, @c_ErrMsg, 'isp_Combine_Load'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_Starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO