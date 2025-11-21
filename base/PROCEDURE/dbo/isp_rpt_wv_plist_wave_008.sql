SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_008                             */
/* Creation Date: 01-Sep-2023                                              */
/* Copyright: MAERSK                                                       */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-20000 - Convert to Logi Report -                           */
/*                      r_dw_print_wave_pickslip_26   (KR)                 */
/*          WMS-23483 - [KR] ADIDAS_Picking Slip Report Data Window_CR     */
/*                                                                         */
/* Called By: RPT_WV_PLIST_WAVE_008                                        */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 01-Sep-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_008]
   @c_Wavekey_Type  NVARCHAR(15)
 , @c_PreGenRptData NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt            INT
         , @n_Continue             INT
         , @b_Success              INT
         , @n_Err                  INT
         , @c_ErrMsg               NVARCHAR(255)
         , @c_Wavekey              NVARCHAR(10)
         , @c_Type                 NCHAR(5)
         , @n_WaveSeqOfDay         INT
         , @dt_Adddate             DATETIME
         , @d_Adddate              DATETIME
         , @n_RowNum               INT
         , @c_PickSlipNo           NVARCHAR(10)
         , @c_PickHeaderKey        NVARCHAR(10)
         , @c_PickSlipNo_PD        NVARCHAR(10)
         , @c_Zone                 NVARCHAR(10)
         , @c_PickDetailKey        NVARCHAR(10)
         , @c_Orderkey             NVARCHAR(10)
         , @c_Loadkey              NVARCHAR(10)
         , @c_OrderLineNumber      NVARCHAR(5)
         , @CUR_PSLIP              CURSOR
         , @CUR_PD                 CURSOR
         , @CUR_PACKSLIP           CURSOR
         , @c_wavetype             NVARCHAR(36)  = N''
         , @c_OrderSelectionKey    NVARCHAR(20)  = N''
         , @c_ColorCode            NVARCHAR(30)  = N''
         , @bInValid               BIT
         , @cTableName             NVARCHAR(30)
         , @cValue                 NVARCHAR(4000)
         , @cColumnName            NVARCHAR(250)
         , @cCondLevel             NVARCHAR(10)
         , @cColName               NVARCHAR(128)
         , @cColType               NVARCHAR(128)
         , @cOrAnd                 NVARCHAR(10)
         , @cOperator              NVARCHAR(10)
         , @nTotalOrders           INT
         , @nTotalOpenQty          INT
         , @nPreCondLevel          INT
         , @nCurrCondLevel         INT
         , @noOfOrdKey             INT
         , @noOfOrdKeyTmp          INT
         , @c_tmpOrderSelectionKey NVARCHAR(10)  = N''
         , @c_orderSelectionKey2   NVARCHAR(10)  = N''
         , @c_tmpCondNo            NVARCHAR(10)  = N''
         , @nMaxOrders             INT
         , @nMaxOpenQty            INT
         , @cGroupBy               NVARCHAR(2000)
         , @cSQL                   NVARCHAR(MAX)
         , @cSQL2                  NVARCHAR(MAX)
         , @c_OrdDocType           NVARCHAR(5)
         , @n_cntOrdtype           INT

   CREATE TABLE #TEMPORDKEY
   (
      orderkey   NVARCHAR(10)
    , OrdDocType NVARCHAR(5)
   )

   CREATE TABLE #TMPOSK
   (
      OrderSelectionKey NVARCHAR(40)
   )

   SET @cGroupBy = N' GROUP BY
                       ORDERS.OrderKey
                      ,isnull(ORDERS.DocType,'''')
                      ,ORDERS.ExternOrderkey
                      ,ORDERS.OpenQty'

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_Err = 0
   SET @c_ErrMsg = ''

   CREATE TABLE #TMP_PSLIP
   (
      RowNum        INT          IDENTITY(1, 1) NOT NULL PRIMARY KEY
    , Storerkey     NVARCHAR(15) NULL
    , Wavekey       NVARCHAR(10) NULL
    , PickHeaderKey NVARCHAR(10) NULL
    , PutawayZone   NVARCHAR(10) NULL
    , Printedflag   NCHAR(1)     NULL
    , NoOfSku       INT          NULL
    , NoOfPickLines INT          NULL
    , OrdSelectkey  NVARCHAR(20) NULL
    , ColorCode     NVARCHAR(20) NULL
    , ORDDoctype    NVARCHAR(10) NULL
   )

   SET @c_Wavekey = SUBSTRING(@c_Wavekey_Type, 1, 10)
   SET @c_Type = SUBSTRING(@c_Wavekey_Type, 11, 2)
   SET @c_PreGenRptData = IIF(@c_PreGenRptData = 'Y', 'Y', '')

   SELECT TOP 1 @c_wavetype = RTRIM(WaveType)
   FROM WAVE (NOLOCK)
   WHERE WaveKey = @c_Wavekey

   SELECT @noOfOrdKey = COUNT(OrderKey)
   FROM WAVEDETAIL (NOLOCK)
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey

   CREATE TABLE #TEMPOSK
   (
      OrderSelectionKey NVARCHAR(40)
    , NoOfCond          INT NULL
   )
   INSERT INTO #TEMPOSK (OrderSelectionKey)
   SELECT DISTINCT OrderSelection.OrderSelectionKey
   FROM ORDERS WITH (NOLOCK)
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)
   JOIN OrderSelection WITH (NOLOCK) ON  (ORDERS.StorerKey >= OrderSelection.StorerKeyStart)
                                     AND (ORDERS.StorerKey <= OrderSelection.StorerKeyEnd)
                                     AND (ORDERS.OrderDate >= OrderSelection.OrderDateStart)
                                     AND (ORDERS.OrderDate <= OrderSelection.OrderDateEnd)
   JOIN WAVEDETAIL (NOLOCK) ON (ORDERS.OrderKey = WAVEDETAIL.OrderKey)
   JOIN OrderSelectionCondition (NOLOCK) ON (OrderSelectionCondition.OrderSelectionKey = OrderSelection.OrderSelectionKey)
   LEFT JOIN V_StorerConfig2 SC WITH (NOLOCK) ON  ORDERS.StorerKey = SC.storerkey
                                              AND SC.ConfigKey = 'WaveSkipUserdefine08Chk'
   LEFT JOIN OrderInfo WITH (NOLOCK) ON (ORDERS.OrderKey = OrderInfo.OrderKey)
   JOIN WAVE (NOLOCK) ON WAVE.WaveKey = WAVEDETAIL.WaveKey
   WHERE (ORDERS.UserDefine08 = 'Y' OR ISNULL(SC.Svalue, '') = '1')
   AND   (NOT ORDERS.Status IN ( '8', '9' ))
   AND   (ORDERS.ConsigneeKey >= OrderSelection.ConsigneeKeyStart)
   AND   (ORDERS.ConsigneeKey <= OrderSelection.ConsigneeKeyEnd)
   AND   (ORDERS.Type >= OrderSelection.OrderTypeStart)
   AND   (ORDERS.Type <= OrderSelection.OrderTypeEnd)
   AND   (ORDERS.DeliveryDate >= OrderSelection.DeliveryDateStart)
   AND   (ORDERS.DeliveryDate <= OrderSelection.DeliveryDateEnd)
   AND   (ORDERS.Priority >= OrderSelection.OrderPriorityStart)
   AND   (ORDERS.Priority <= OrderSelection.OrderPriorityEnd)
   AND   (ORDERS.IntermodalVehicle >= OrderSelection.CarrierKeyStart)
   AND   (ORDERS.IntermodalVehicle <= OrderSelection.CarrierKeyEnd)
   AND   (ORDERS.OrderKey >= OrderSelection.OrderKeyStart)
   AND   (ORDERS.OrderKey <= OrderSelection.OrderKeyEnd)
   AND   (ORDERS.ExternOrderKey >= OrderSelection.ExternOrderKeyStart)
   AND   (ORDERS.ExternOrderKey <= OrderSelection.ExternOrderKeyEnd)
   AND   (ORDERS.Route >= OrderSelection.RouteStart)
   AND   (ORDERS.Route <= OrderSelection.RouteEnd)
   AND   (ORDERS.Door >= OrderSelection.DoorStart)
   AND   (ORDERS.Door <= OrderSelection.DoorEnd)
   AND   (ORDERS.Stop >= OrderSelection.StopStart)
   AND   (ORDERS.Stop <= OrderSelection.StopEnd)
   AND   (ORDERS.OrderGroup >= OrderSelection.OrderGroupStart)
   AND   (ORDERS.OrderGroup <= OrderSelection.OrderGroupEnd)
   AND   (ISNULL(ORDERS.BuyerPO, '') >= OrderSelection.BuyerPOStart)
   AND   (ISNULL(ORDERS.BuyerPO, '') <= OrderSelection.BuyerPOEnd)
   --AND (ORDERS.UserDefine09 IS NULL OR ORDERS.UserDefine09 = '')  --This is wavekey
   AND   (ORDERS.SOStatus <> 'PENDING')
   AND   (ORDERS.SOStatus NOT IN (  SELECT CODELKUP.Code
                                    FROM CODELKUP WITH (NOLOCK)
                                    WHERE CODELKUP.LISTNAME = 'WBEXCSOSTS' AND CODELKUP.Storerkey = ORDERS.StorerKey ))
   AND   (ISNULL(ORDERS.DocType, '') >= OrderSelection.DocTypeStart)
   AND   (ISNULL(ORDERS.DocType, '') <= OrderSelection.DocTypeEnd)
   AND   (ISNULL(ORDERS.BillToKey, '') >= OrderSelection.BillToKeyStart)
   AND   (ISNULL(ORDERS.BillToKey, '') <= OrderSelection.BillToKeyEnd)
   AND   (ISNULL(ORDERS.M_ISOCntryCode, '') >= OrderSelection.M_ISOCntryCodeStart)
   AND   (ISNULL(ORDERS.M_ISOCntryCode, '') <= OrderSelection.M_ISOCntryCodeEnd)
   AND   (ISNULL(ORDERS.UserDefine05, '') >= OrderSelection.UserDefine05Start)
   AND   (ISNULL(ORDERS.UserDefine05, '') <= OrderSelection.UserDefine05End)
   AND   (ISNULL(ORDERS.SpecialHandling, '') >= OrderSelection.SpecialHandlingStart)
   AND   (ISNULL(ORDERS.SpecialHandling, '') <= OrderSelection.SpecialHandlingEnd)
   AND   (ISNULL(ORDERS.DeliveryNote, '') >= OrderSelection.DeliveryNoteStart)
   AND   (ISNULL(ORDERS.DeliveryNote, '') <= OrderSelection.DeliveryNoteEnd)
   AND   (ORDERS.Facility = CASE WHEN ISNULL(OrderSelection.facility, '') <> '' THEN OrderSelection.facility
                                 ELSE ORDERS.Facility END)
   AND   WAVEDETAIL.WaveKey = @c_Wavekey

   DECLARE CUR_NOOFCOND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT OrderSelectionKey
   FROM #TEMPOSK
   WHERE OrderSelectionKey = @c_wavetype
   OPEN CUR_NOOFCOND
   FETCH NEXT FROM CUR_NOOFCOND
   INTO @c_tmpOrderSelectionKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_tmpCondNo = COUNT(OrderSelectionCondition.OrderSelectionLineNumber)
      FROM OrderSelectionCondition (NOLOCK)
      WHERE OrderSelectionCondition.OrderSelectionKey = @c_tmpOrderSelectionKey
      AND   OrderSelectionCondition.Type = 'CONDITION'

      UPDATE #TEMPOSK
      SET NoOfCond = @c_tmpCondNo
      WHERE OrderSelectionKey = @c_tmpOrderSelectionKey
      SET @c_tmpCondNo = N''
      FETCH NEXT FROM CUR_NOOFCOND
      INTO @c_tmpOrderSelectionKey
   END

   DECLARE CUR_OSK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderSelectionKey
   FROM #TEMPOSK
   WHERE OrderSelectionKey = @c_wavetype
   ORDER BY NoOfCond DESC

   OPEN CUR_OSK

   FETCH NEXT FROM CUR_OSK
   INTO @c_tmpOrderSelectionKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DECLARE CUR_BUILD_WAVE_COND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT FieldName
           , ISNULL([Value], '')
           , ConditionGroup
           , OperatorAndOr
           , Operator
      FROM OrderSelectionCondition WITH (NOLOCK)
      WHERE OrderSelectionKey = @c_tmpOrderSelectionKey AND [Type] = 'CONDITION'
      ORDER BY OrderSelectionLineNumber

      OPEN CUR_BUILD_WAVE_COND
      FETCH NEXT FROM CUR_BUILD_WAVE_COND
      INTO @cColumnName
         , @cValue
         , @cCondLevel
         , @cOrAnd
         , @cOperator

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @cColumnName = 'ORDERS.Status'
            GOTO NEXT

         IF ISNUMERIC(@cCondLevel) = 1
         BEGIN
            IF @nPreCondLevel = 0
               SET @nPreCondLevel = CAST(@cCondLevel AS INT)
            SET @nCurrCondLevel = CAST(@cCondLevel AS INT)
         END

         SET @cTableName = LEFT(@cColumnName, CHARINDEX('.', @cColumnName) - 1)
         SET @cColName = SUBSTRING(
                            @cColumnName
                          , CHARINDEX('.', @cColumnName) + 1
                          , LEN(@cColumnName) - CHARINDEX('.', @cColumnName))

         SET @cColType = N''
         SELECT @cColType = DATA_TYPE
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_NAME = @cTableName AND COLUMN_NAME = @cColName

         IF ISNULL(RTRIM(@cColType), '') = ''
         BEGIN
            SET @bInValid = 1
         -- SET @cErrorMsg = 'Invalid Column Name: ' + @cColumnName
         -- GOTO QUIT
         END

         IF @cColType = 'DATETIME' AND ISDATE(@cValue) <> 1
         BEGIN
            IF @cValue IN ( 'today', 'now', 'startofmonth', 'endofmonth', 'startofyear', 'endofyear' )
            BEGIN
               SET @cValue = CASE @cValue
                                  WHEN 'today' THEN LEFT(CONVERT(VARCHAR(30), GETDATE(), 120), 10)
                                  WHEN 'now' THEN CONVERT(VARCHAR(30), GETDATE(), 120)
                                  WHEN 'startofmonth' THEN
                                     CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-'
                                     + ('0' + CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2))) + ('-01')
                                  WHEN 'endofmonth' THEN
                                     CONVERT(
                                        VARCHAR(30), DATEADD(s, -1, DATEADD(mm, DATEDIFF(m, 0, GETDATE()) + 1, 0)), 120)
                                  WHEN 'startofyear' THEN CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-01-01'
                                  WHEN 'endofyear' THEN
                                     CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(4)) + '-12-31 23:59:59' END
            END
            ELSE
            BEGIN
               SET @bInValid = 1
            -- SET @cErrorMsg = 'Invalid Date Format: ' + @cValue
            -- GOTO QUIT
            END
         END

         IF @nPreCondLevel < @nCurrCondLevel
         BEGIN
            SET @cSQL2 = @cSQL2 + N' ' + master.dbo.fnc_GetCharASCII(13) + N' ' + @cOrAnd + N' ('
            SET @nPreCondLevel = @nCurrCondLevel
         END
         ELSE IF @nPreCondLevel > @nCurrCondLevel
         BEGIN
            SET @cSQL2 = @cSQL2 + N') ' + master.dbo.fnc_GetCharASCII(13) + N' ' + @cOrAnd
            SET @nPreCondLevel = @nCurrCondLevel
         END
         ELSE
         BEGIN
            SET @cSQL2 = @cSQL2 + N' ' + master.dbo.fnc_GetCharASCII(13) + N' ' + @cOrAnd
         END

         IF @cColType IN ( 'CHAR', 'NVARCHAR', 'VARCHAR', 'NCHAR' ) --NJOW01
            SET @cSQL2 = @cSQL2 + N' ' + @cColumnName + N' ' + @cOperator
                         + CASE WHEN @cOperator = 'IN' THEN
                                   CASE WHEN LEFT(RTRIM(LTRIM(@cValue)), 1) <> '(' THEN '('
                                        ELSE '' END + RTRIM(LTRIM(@cValue))
                                   + CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)), 1) <> ')' THEN ') '
                                          ELSE '' END
                                ELSE
                                   ' N' + CASE WHEN LEFT(RTRIM(LTRIM(@cValue)), 1) <> '''' THEN ''''
                                               ELSE '' END + RTRIM(LTRIM(@cValue))
                                   + CASE WHEN RIGHT(RTRIM(LTRIM(@cValue)), 1) <> '''' THEN ''' '
                                          ELSE '' END END
         ELSE IF @cColType IN ( 'FLOAT', 'MONEY', 'INT', 'DECIMAL', 'NUMERIC', 'TINYINT', 'REAL', 'BIGINT' )
            SET @cSQL2 = @cSQL2 + N' ' + @cColumnName + N' ' + @cOperator + RTRIM(@cValue)
         ELSE IF @cColType IN ( 'DATETIME' )
            SET @cSQL2 = @cSQL2 + N' ' + @cColumnName + N' ' + @cOperator + N' ''' + @cValue + N''' '

         NEXT:
         FETCH NEXT FROM CUR_BUILD_WAVE_COND
         INTO @cColumnName
            , @cValue
            , @cCondLevel
            , @cOrAnd
            , @cOperator
      END
      CLOSE CUR_BUILD_WAVE_COND
      DEALLOCATE CUR_BUILD_WAVE_COND

      WHILE @nPreCondLevel > 1
      BEGIN
         SET @cSQL2 = @cSQL2 + N') '
         SET @nPreCondLevel = @nPreCondLevel - 1
      END

      SET @cSQL = N' INSERT INTO #TEMPORDKEY '
                  + N'select DISTINCT isnull(ORDERS.orderkey,''''),isnull(ORDERS.DocType,'''') from wavedetail WITH (NOLOCK)'
                  + N'JOIN ORDERS WITH (NOLOCK) ON wavedetail.ORDERKEY = ORDERS.ORDERKEY '
                  + N'JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey) '
                  + N'LEFT JOIN ORDERINFO WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERINFO.Orderkey) '
                  + N'where wavedetail.wavekey = ' + @c_Wavekey
      SET @cSQL2 = RTRIM(@cSQL2) + CHAR(13) + @cGroupBy

      EXEC (@cSQL + ' ' + @cSQL2)

      SET @n_cntOrdtype = 1
      SET @c_OrdDocType = N''

      SELECT @n_cntOrdtype = COUNT(DISTINCT OrdDocType)
      FROM #TEMPORDKEY

      IF @n_cntOrdtype = 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
         SET @n_Err = 81090 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_ErrMsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + N': wave not had doctype (isp_RPT_WV_PLIST_WAVE_008)'
                         + N' ( ' + N' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + N' ) '
         GOTO QUIT_SP
      END

      IF @n_cntOrdtype = 1
      BEGIN

         SELECT TOP 1 @c_OrdDocType = OrdDocType
         FROM #TEMPORDKEY

         IF ISNULL(@c_OrdDocType, '') = ''
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
            SET @n_Err = 81090 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                            + N': wave not had doctype (isp_RPT_WV_PLIST_WAVE_008)' + N' ( ' + N' SQLSvr MESSAGE='
                            + RTRIM(@c_ErrMsg) + N' ) '
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
         SET @n_Err = 81080 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_ErrMsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                         + N': wave consists more than 1 doctype (isp_RPT_WV_PLIST_WAVE_008)' + N' ( '
                         + N' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + N' ) '
         GOTO QUIT_SP
      END

      SELECT @noOfOrdKeyTmp = COUNT(orderkey)
      FROM #TEMPORDKEY

      IF (@noOfOrdKeyTmp = @noOfOrdKey)
      BEGIN
         INSERT INTO #TMPOSK (OrderSelectionKey)
         VALUES (@c_tmpOrderSelectionKey)
         TRUNCATE TABLE #TEMPORDKEY
      END

      TRUNCATE TABLE #TEMPORDKEY

      SET @cSQL2 = N''
      SET @noOfOrdKeyTmp = ''

      FETCH NEXT FROM CUR_OSK
      INTO @c_tmpOrderSelectionKey
   END
   CLOSE CUR_OSK
   DEALLOCATE CUR_OSK

   IF NOT EXISTS (  SELECT TOP 1 *
                    FROM #TMPOSK) --Add dummy value
   BEGIN
      INSERT INTO #TMPOSK
      VALUES ('0')
   END

   SELECT @c_OrderSelectionKey = RTRIM(OrderSelectionKey)
   FROM #TMPOSK
   WHERE OrderSelectionKey = RTRIM(@c_wavetype)

   IF (@c_OrderSelectionKey <> @c_wavetype)
   BEGIN
      SET @n_Continue = 3
      SET @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
      SET @n_Err = 81070 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_ErrMsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                      + N': Wavetype and OrderSelectionKey Mismatch (isp_RPT_WV_PLIST_WAVE_008)' + N' ( '
                      + N' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + N' ) '
      GOTO QUIT_SP
   END

   INSERT INTO #TMP_PSLIP (Storerkey, Wavekey, PickHeaderKey, PutawayZone, Printedflag, NoOfSku, NoOfPickLines
                         , OrdSelectkey, ColorCode, ORDDoctype)
   SELECT PD.Storerkey
        , WD.WaveKey
        , PickHeaderKey = CASE WHEN ISNULL(RTRIM(PH.PickHeaderKey), '') <> '' THEN ISNULL(RTRIM(PH.PickHeaderKey), '')
                               ELSE ISNULL(RTRIM(PHORD.PickHeaderKey), '')END
        , LOC.PutawayZone
        , Printedflag = CASE WHEN ISNULL(RTRIM(PH.PickHeaderKey), '') = '' THEN 'N'
                             ELSE 'Y' END
        , NoOfSku = COUNT(DISTINCT PD.Sku)
        , NoOfPickLines = COUNT(DISTINCT PD.PickDetailKey)
        , Orderselectionkey = CASE WHEN @c_OrderSelectionKey = '0' THEN ''
                                   ELSE @c_OrderSelectionKey END
        , ColorCode = ISNULL(CLR.Code, '')
        , OrdDoctype = @c_OrdDocType
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
   JOIN LOC LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
   LEFT JOIN RefKeyLookup RL WITH (NOLOCK) ON (PD.PickDetailKey = RL.PickDetailkey)
   LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON (RL.Pickslipno = PH.PickHeaderKey)
   LEFT JOIN PICKHEADER PHORD WITH (NOLOCK) ON (PD.OrderKey = PHORD.OrderKey)
   LEFT JOIN CODELKUP CLR WITH (NOLOCK) ON CLR.LISTNAME = 'OSKCOLOR' AND CLR.Long = @c_OrderSelectionKey
   WHERE WD.WaveKey = @c_Wavekey AND PD.Status < '5'
   GROUP BY PD.Storerkey
          , WD.WaveKey
          , ISNULL(RTRIM(PH.PickHeaderKey), '')
          , ISNULL(RTRIM(PHORD.PickHeaderKey), '')
          , LOC.PutawayZone
          , ISNULL(CLR.Code, '')
   ORDER BY ISNULL(RTRIM(PH.PickHeaderKey), '')
          , ISNULL(RTRIM(PHORD.PickHeaderKey), '')
          , LOC.PutawayZone

   IF @c_PreGenRptData = 'Y'
   BEGIN
      SET @CUR_PSLIP = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT RowNum
           , PickHeaderKey
           , PutawayZone
      FROM #TMP_PSLIP
      ORDER BY RowNum

      OPEN @CUR_PSLIP

      FETCH NEXT FROM @CUR_PSLIP
      INTO @n_RowNum
         , @c_PickSlipNo
         , @c_Zone

      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @c_PickSlipNo = ''
         BEGIN
            EXECUTE nspg_GetKey 'PICKSLIP'
                              , 9
                              , @c_PickSlipNo OUTPUT
                              , @b_Success OUTPUT
                              , @n_Err OUTPUT
                              , @c_ErrMsg OUTPUT

            IF @b_Success <> 1
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 81010
               SET @c_ErrMsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                               + N': Get PickSlip # Failed. (isp_RPT_WV_PLIST_WAVE_008)'
               BREAK
            END

            SET @c_PickSlipNo = N'P' + @c_PickSlipNo

            INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, OrderKey, ExternOrderKey, LoadKey, PickType, Zone
                                  , ConsoOrderKey, TrafficCop)
            VALUES (@c_PickSlipNo, @c_Wavekey, '', @c_PickSlipNo, '', '0', 'LP', @c_Zone, '')

            SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
               SET @n_Err = 81020 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_ErrMsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                               + N': Insert PICKHEADER Failed (isp_RPT_WV_PLIST_WAVE_008)' + N' ( '
                               + N' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + N' ) '
               GOTO QUIT_SP
            END

            UPDATE #TMP_PSLIP
            SET PickHeaderKey = @c_PickSlipNo
            WHERE RowNum = @n_RowNum AND PickHeaderKey = ''
         END

         SET @CUR_PD = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey
              , PD.OrderKey
              , PD.OrderLineNumber
              , ISNULL(RTRIM(PD.PickSlipNo), '')
         FROM WAVEDETAIL WD WITH (NOLOCK)
         JOIN PICKDETAIL PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
         JOIN LOC LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
         WHERE WD.WaveKey = @c_Wavekey AND LOC.PutawayZone = @c_Zone
         ORDER BY PD.PickDetailKey

         OPEN @CUR_PD

         FETCH NEXT FROM @CUR_PD
         INTO @c_PickDetailKey
            , @c_Orderkey
            , @c_OrderLineNumber
            , @c_PickSlipNo_PD

         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF NOT EXISTS (  SELECT 1
                             FROM RefKeyLookup RL WITH (NOLOCK)
                             WHERE PickDetailkey = @c_PickDetailKey)
            BEGIN
               INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber)
               VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_Orderkey, @c_OrderLineNumber)

               SET @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 81030
                  SET @c_ErrMsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + N': Insert RefKeyLookup Failed. (isp_RPT_WV_PLIST_WAVE_008)'
                  GOTO QUIT_SP
               END
            END

            IF @c_PickSlipNo <> @c_PickSlipNo_PD
            BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET PickSlipNo = @c_PickSlipNo
                 , EditWho = SUSER_NAME()
                 , EditDate = GETDATE()
                 , TrafficCop = NULL
               WHERE PickDetailKey = @c_PickDetailKey

               SET @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                  SET @n_Err = 81040 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_ErrMsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + N': UPDATE Pickdetail Failed (isp_RPT_WV_PLIST_WAVE_008)' + N' ( '
                                  + N' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + N' ) '
                  GOTO QUIT_SP
               END
            END

            FETCH NEXT FROM @CUR_PD
            INTO @c_PickDetailKey
               , @c_Orderkey
               , @c_OrderLineNumber
               , @c_PickSlipNo_PD
         END

         CLOSE @CUR_PD
         DEALLOCATE @CUR_PD

         FETCH NEXT FROM @CUR_PSLIP
         INTO @n_RowNum
            , @c_PickSlipNo
            , @c_Zone

      END
      CLOSE @CUR_PSLIP
      DEALLOCATE @CUR_PSLIP
   END

   QUIT_SP:
   IF ISNULL(@c_PreGenRptData, '') = ''
   BEGIN
      SELECT TMP.Storerkey
           , TMP.Wavekey
           , TMP.PickHeaderKey
           , TMP.PutawayZone
           , TMP.Printedflag
           , TMP.NoOfSku
           , TMP.NoOfPickLines
           , TMP.OrdSelectkey
           , TMP.ColorCode
           , TMP.ORDDoctype
      FROM #TMP_PSLIP TMP
      ORDER BY TMP.PickHeaderKey
             , TMP.PutawayZone
   END

   IF CURSOR_STATUS('VARIABLE', '@CUR_PSLIP') IN ( 0, 1 )
   BEGIN
      CLOSE @CUR_PSLIP
      DEALLOCATE @CUR_PSLIP
   END

   IF CURSOR_STATUS('VARIABLE', '@CUR_PD') IN ( 0, 1 )
   BEGIN
      CLOSE @CUR_PD
      DEALLOCATE @CUR_PD
   END

   IF @n_Continue = 3 -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_RPT_WV_PLIST_WAVE_008'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO