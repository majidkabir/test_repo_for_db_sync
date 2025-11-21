SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: msp_BEJ_BuildWave                                       */
/* Creation Date: 2024-10-17                                            */
/* Copyright: Maersk Logistics                                          */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: UWP-24682 [FCR-764] [HUSQ] Outbound Wave update             */
/*        :                                                             */
/* Called By: Call by SQL Scheduler Job                                 */
/*          :                                                           */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2024-10-17  Wan      1.0   Created.                                  */
/* 2024-11-08  ALT028   1.1   FCR-764 - Revise logic.                   */
/* 2024-11-12  WFA015   1.2   FCR-764 - Merge & Revise script.          */
/*                            - Update latest Orders.ShipperKey only.   */
/************************************************************************/

CREATE   PROC [dbo].[msp_BEJ_BuildWave]
     @c_StorerKey   NVARCHAR(15)   = ''
   , @c_Facility    NVARCHAR(5)    = ''
   , @c_OtherConfig NVARCHAR(4000) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT            = @@TRANCOUNT
         , @n_Continue        INT            = 1
         , @b_Success         INT            = 1
         , @n_Err             INT            = 0
         , @c_ErrMsg          NVARCHAR(255)  = ''

         , @n_FromPos         INT            = 0
         , @n_ToPos           INT            = 0
         , @n_MaxOpenQty      INT            = 0

         , @n_MaxOpenQty01    INT            = 0
         , @n_MaxOpenQty02    INT            = 0
         , @n_MaxOpenQty03    INT            = 0
         , @n_MaxOpenQty04    INT            = 0
         , @n_MaxOpenQty05    INT            = 0
         , @n_MaxOrdPerBld    INT            = 0
         , @n_MaxOrdPerBld01  INT            = 0
         , @n_MaxOrdPerBld02  INT            = 0
         , @n_MaxOrdPerBld03  INT            = 0
         , @n_MaxOrdPerBld04  INT            = 0
         , @n_MaxOrdPerBld05  INT            = 0

         , @c_BuildParmKey    NVARCHAR(10)   = ''
         , @c_BuildParmLineNo NVARCHAR(10)   = ''

         , @c_GenByBuildValue NCHAR(1)       = 'N'
         , @c_SQLBuildWave    NVARCHAR(MAX)  = ''
         , @c_UserName        NVARCHAR(128)  = SUSER_SNAME()
         , @dt_Date_Fr        DATETIME       = NULL
         , @dt_Date_To        DATETIME       = NULL

         , @c_OrderKey        NVARCHAR(10)   = ''
         , @c_WaveKey         NVARCHAR(10)   = ''
         , @c_ShipperKey      NVARCHAR(15)   = ''
         , @c_ParcelType      NVARCHAR(10)   = ''
         , @c_ParcelTypes     NVARCHAR(500)  = ''
         , @c_ParcelCategory  NVARCHAR(30)   = ''
         , @d_DeliveryDate    DATETIME       = ''

         , @n_Cube_Retail     FLOAT          = 0.00
         , @n_Cube_Box5       FLOAT          = 0.00
         , @n_Cube_Ord        FLOAT          = 0.00
         , @n_OpenQty         INT            = 0

         , @c_SQL             NVARCHAR(MAX)  = ''
         , @c_SQLParms        NVARCHAR(500)  = ''
         , @c_SQLMaxOrd       NVARCHAR(500)  = ''
         , @b_Debug           INT            = 0

         , @CUR_ORD           CURSOR

   IF RIGHT(ISNULL(TRIM(@c_OtherConfig),''),2) = '##'
   BEGIN
      SET @b_Debug = 1
      SET @c_OtherConfig = SUBSTRING(@c_OtherConfig, 1, LEN(@c_OtherConfig)-2)
   END

   SELECT @c_BuildParmKey = dbO.fnc_GetParamValueFromString ('@c_BuildParmKey',@c_OtherConfig, @c_BuildParmKey)

   IF @b_Debug = 1
   BEGIN
      PRINT '@c_BuildParmKey: ' + @c_BuildParmKey
          + ', Now = ' + CONVERT(NVARCHAR(25), GETDATE(),121)
          + ', @c_OtherConfig: ' + @c_OtherConfig
   END

   IF @c_BuildParmKey = ''
   BEGIN
      GOTO QUIT_SP
   END

   BEGIN TRAN
   --Tables use in WM.lsp_Build_Wave
   IF OBJECT_ID('tempdb..#TMP_ORDERS','u') IS NULL
   BEGIN
      CREATE TABLE #TMP_ORDERS
      (
         OrderKey NVARCHAR(10)   NULL
      )
   END
   ELSE
   BEGIN
      TRUNCATE TABLE #TMP_ORDERS;
   END

   IF OBJECT_ID('tempdb..#TMP_SKUTOTQTY','u') IS NULL     --(Wan10)
   BEGIN
      CREATE TABLE #TMP_SKUTOTQTY
      (
        RowID          INT            NOT NULL DEFAULT(0)
      , StorerKey      NVARCHAR(15)   NOT NULL DEFAULT('')
      , Sku            NVARCHAR(20)   NOT NULL DEFAULT('')
      , Qty            INT            NOT NULL DEFAULT(0)

      )
   END
   ELSE
   BEGIN
      TRUNCATE TABLE #TMP_SKUTOTQTY;
   END

   --Table uses in current SP
   IF OBJECT_ID('tempdb..#TMP_ORD','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_ORD;
   END

   CREATE TABLE #TMP_ORD
   (
     OrderKey        NVARCHAR(10)   NOT NULL DEFAULT ('')   PRIMARY KEY
   , WaveKey         NVARCHAR(10)   NOT NULL DEFAULT ('')
   , ParcelType      NVARCHAR(30)   NOT NULL DEFAULT ('')
   , ParcelCategory  NVARCHAR(60)   NOT NULL DEFAULT ('')
   , DeliveryDate    DATETIME       NULL
   )

   IF OBJECT_ID('tempdb..#TMP_CODELKUP','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMP_CODELKUP;
   END

   CREATE TABLE #TMP_CODELKUP
   ( ListName    NVARCHAR(10)   NOT NULL    DEFAULT ('')
   , Code        NVARCHAR(30)   NOT NULL    DEFAULT ('')
   , Short       NVARCHAR(10)   NOT NULL    DEFAULT ('')
   , UDF01       NVARCHAR(60)   NOT NULL    DEFAULT ('')
   , UDF02       NVARCHAR(60)   NOT NULL    DEFAULT ('')
   , UDF03       NVARCHAR(60)   NOT NULL    DEFAULT ('')
   , UDF04       NVARCHAR(60)   NOT NULL    DEFAULT ('')
   , UDF05       NVARCHAR(60)   NOT NULL    DEFAULT ('')
   , StorerKey   NVARCHAR(15)   NOT NULL    DEFAULT ('')
   , Code2       NVARCHAR(30)   NOT NULL    DEFAULT ('')
   )

   SELECT  @n_MaxOrdPerBld01= CASE WHEN BP.Restriction01 = '1_MaxOrderPerBuild' THEN BP.RestrictionValue01  ELSE 0 END
         , @n_MaxOrdPerBld02= CASE WHEN BP.Restriction02 = '1_MaxOrderPerBuild' THEN BP.RestrictionValue02  ELSE 0 END
         , @n_MaxOrdPerBld03= CASE WHEN BP.Restriction03 = '1_MaxOrderPerBuild' THEN BP.RestrictionValue03  ELSE 0 END
         , @n_MaxOrdPerBld04= CASE WHEN BP.Restriction04 = '1_MaxOrderPerBuild' THEN BP.RestrictionValue04  ELSE 0 END
         , @n_MaxOrdPerBld05= CASE WHEN BP.Restriction05 = '1_MaxOrderPerBuild' THEN BP.RestrictionValue05  ELSE 0 END
         , @n_MaxOpenQty01  = CASE WHEN BP.Restriction01 = '2_MaxQtyPerBuild'   THEN BP.RestrictionValue01  ELSE 0 END
         , @n_MaxOpenQty02  = CASE WHEN BP.Restriction02 = '2_MaxQtyPerBuild'   THEN BP.RestrictionValue02  ELSE 0 END
         , @n_MaxOpenQty03  = CASE WHEN BP.Restriction03 = '2_MaxQtyPerBuild'   THEN BP.RestrictionValue03  ELSE 0 END
         , @n_MaxOpenQty04  = CASE WHEN BP.Restriction04 = '2_MaxQtyPerBuild'   THEN BP.RestrictionValue04  ELSE 0 END
         , @n_MaxOpenQty05  = CASE WHEN BP.Restriction05 = '2_MaxQtyPerBuild'   THEN BP.RestrictionValue05  ELSE 0 END
   FROM BUILDPARM BP WITH (NOLOCK)
   WHERE BP.BuildParmKey = @c_BuildParmKey

   SET @n_MaxOrdPerBld= @n_MaxOrdPerBld01

   IF @n_MaxOrdPerBld > 0
   BEGIN
      SET @c_SQLMaxOrd = N',RestrictionBuildValue01=@n_MaxOrdPerBld'
   END
   IF @n_MaxOrdPerBld = 0
  BEGIN
      SET @n_MaxOrdPerBld = @n_MaxOrdPerBld02
      SET @c_SQLMaxOrd = N',RestrictionBuildValue02=@n_MaxOrdPerBld'
   END
   IF @n_MaxOrdPerBld = 0
   BEGIN
      SET @n_MaxOrdPerBld = @n_MaxOrdPerBld03
      SET @c_SQLMaxOrd = N',RestrictionBuildValue03=@n_MaxOrdPerBld'
   END
   IF @n_MaxOrdPerBld = 0
   BEGIN
      SET @n_MaxOrdPerBld = @n_MaxOrdPerBld04
      SET @c_SQLMaxOrd = N',RestrictionBuildValue04=@n_MaxOrdPerBld'
   END
   IF @n_MaxOrdPerBld = 0
   BEGIN
      SET @n_MaxOrdPerBld = @n_MaxOrdPerBld05
      SET @c_SQLMaxOrd = N',RestrictionBuildValue05=@n_MaxOrdPerBld'
   END

   SET @n_MaxOpenQty= @n_MaxOpenQty01
   IF @n_MaxOpenQty = 0   SET @n_MaxOpenQty = @n_MaxOpenQty02
   IF @n_MaxOpenQty = 0   SET @n_MaxOpenQty = @n_MaxOpenQty03
   IF @n_MaxOpenQty = 0   SET @n_MaxOpenQty = @n_MaxOpenQty04
   IF @n_MaxOpenQty = 0   SET @n_MaxOpenQty = @n_MaxOpenQty05

   EXEC [WM].[lsp_Build_Wave]
        @c_BuildParmKey   = @c_BuildParmKey
      , @c_Facility       = @c_Facility
      , @c_StorerKey      = @c_StorerKey
      , @c_BuildWaveType  = 'ANALYSIS'
      , @c_GenByBuildValue= @c_GenByBuildValue
      , @c_SQLBuildWave   = @c_SQLBuildWave OUTPUT
      , @n_BatchNo        = 0
      , @b_Success        = @b_Success      OUTPUT
      , @n_err            = @n_err          OUTPUT
      , @c_ErrMsg         = @c_ErrMsg       OUTPUT
      , @c_UserName       = @c_UserName
      , @dt_Date_Fr       = @dt_Date_Fr
      , @dt_Date_To       = @dt_Date_To

   IF @b_Debug = 1
   BEGIN
      PRINT ''
      PRINT 'BuildWaveType:   ' + 'ANALYSIS'                          + CHAR(13)
          + 'BuildParmKey:    ' + ISNULL(TRIM(@c_BuildParmKey),'')    + CHAR(13)
          + 'GenByBuildValue: ' + ISNULL(TRIM(@c_GenByBuildValue),'') + CHAR(13)
          + 'SQLBuildWave:    ' + ISNULL(TRIM(@c_SQLBuildWave),'')    + CHAR(13)
          + 'ErrMsg:          ' + CAST(@b_Success AS CHAR(5))
                                + ISNULL(TRIM(@c_ErrMsg),'')          + CHAR(13)
   END

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
   END

   IF @n_Continue = 1
   BEGIN
      SET @n_FromPos = CHARINDEX('FROM ', @c_SQLBuildWave , 1)
      SET @n_ToPos   = LEN(@c_SQLBuildWave) - @n_FromPos + 1

      SET @c_SQL  = N'SELECT ORDERS.OrderKey, CONVERT(VARCHAR(10), ORDERS.DeliveryDate, 121) '
                  + ' ' + CHAR(13) + SUBSTRING(@c_SQLBuildWave, @n_FromPos, @n_ToPos)

      SET @c_SQLParms = N'@c_Facility     NVARCHAR(5)'
                      + ',@c_StorerKey    NVARCHAR(15)'
                      + ',@n_MaxOpenQty   INT'

      INSERT INTO #TMP_ORD (OrderKey, DeliveryDate)
      EXEC SP_EXECUTESQL
            @c_SQL
         ,  @c_SQLParms
         ,  @c_Facility
         ,  @c_StorerKey
         ,  @n_MaxOpenQty

      INSERT INTO #TMP_CODELKUP
         (ListName, Code, Short, UDF01, UDF02, UDF03, UDF04, UDF05, StorerKey,Code2)
      SELECT ListName, Code
           , Short = ISNULL(Short,'')
           , UDF01, UDF02
           , IIF(ISNUMERIC(UDF03)= 1, UDF03,'0.00')
           , IIF(ISNUMERIC(UDF04)= 1, UDF04,'0.00')
           , UDF05
           , StorerKey, Code2
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName  = 'HUSQPKTYPE'
      AND   StorerKey = @c_StorerKey

      IF NOT EXISTS (SELECT 1 FROM #TMP_CODELKUP 
                     WHERE ListName  = 'HUSQPKTYPE'
                     AND   StorerKey = @c_StorerKey 
                     AND   Short     = 'UNKNOWN'
                     AND   UDF01     = 'UNKNOWN'
                  )
      BEGIN 
         INSERT INTO #TMP_CODELKUP
         (ListName, Code, Short, UDF01, UDF02, UDF03, UDF04, UDF05, StorerKey, Code2)
         VALUES ('HUSQPKTYPE', '', 'UNKNOWN','UNKNOWN','','','','', @c_StorerKey, '')
      END

      INSERT INTO #TMP_CODELKUP
         (ListName, Code, Short, UDF01, UDF02, UDF03, UDF04, UDF05, StorerKey,Code2)
      SELECT ListName, Code
           , Short = ISNULL(Short,'')
           , UDF01, UDF02, UDF03, UDF04, UDF05
           , StorerKey,Code2
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName  = 'WSCourier'
      AND   StorerKey = @c_StorerKey

      SELECT TOP 1 @n_Cube_Retail = T.UDF04
      FROM #TMP_CODELKUP t
      WHERE T.UDF01 = 'PARCEL'
      ORDER BY TRY_CONVERT (FLOAT, T.UDF04) DESC

      SELECT TOP 1 @n_Cube_Box5 = T.UDF04
      FROM #TMP_CODELKUP t
      WHERE T.UDF01 = 'PARCEL'
      AND   T.Code2 = 'Undersized'
      ORDER BY TRY_CONVERT (FLOAT, T.UDF04) DESC

      IF @b_Debug = 1
      BEGIN
         SELECT '#TMP_ORD', * FROM #TMP_ORD
         SELECT '#TMP_CODELKUP', * FROM #TMP_CODELKUP
      END

      SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT T.OrderKey
      FROM #TMP_ORD T
      ORDER BY T.OrderKey

      OPEN @CUR_ORD
      FETCH NEXT FROM @CUR_ORD INTO @c_OrderKey

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         -- Get Total Cube
         SET @n_Cube_Ord = 0.00
         SET @n_OpenQty  = 0
         SELECT @n_Cube_Ord = SUM(P.WidthUOM3 * P.LengthUOM3 * P.HeightUOM3 * OD.OpenQty)
              , @n_OpenQty  = SUM(OD.OpenQty)
         FROM ORDERDETAIL OD WITH (NOLOCK)
         JOIN SKU S WITH (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.Sku  = OD.Sku
         JOIN PACK P WITH (NOLOCK) ON P.PackKey = S.PackKey
         WHERE OD.OrderKey = @c_OrderKey

         SET @c_ParcelType = ''
         SELECT TOP 1 @c_ParcelType = T.Short
         FROM #TMP_CODELKUP t
         WHERE T.StorerKey = @c_StorerKey
         AND T.UDF01 = 'PARCEL'
         AND @n_Cube_Ord BETWEEN CONVERT(FLOAT, T.UDF03) AND CONVERT(FLOAT, T.UDF04)

         SET @c_ShipperKey = ''
         IF (@n_Cube_Ord > 0 AND @n_Cube_Ord <= @n_Cube_Box5)
             OR ( (@n_Cube_Ord BETWEEN @n_Cube_Box5 AND @n_Cube_Retail )
                   AND @n_OpenQty = 1 )
         BEGIN
            SELECT TOP 1 @c_ShipperKey = T.Short
            FROM #TMP_CODELKUP t
            WHERE T.StorerKey = @c_StorerKey
            AND T.ListName = 'WSCourier'
            AND T.Code = 'FML-1'
         END

         IF @n_Cube_Ord > @n_Cube_Retail
         BEGIN
            SET @c_ParcelType = 'Non-Parcel'
         END
         ELSE IF @n_Cube_Ord > @n_Cube_Box5 AND @n_Cube_Ord <= @n_Cube_Retail
         BEGIN
            IF @n_OpenQty > 1
            BEGIN
               SET @c_ParcelType = 'Non-Parcel'
            END
         END

         IF @c_ParcelType = ''
         BEGIN
            SET @c_ParcelType = 'UNKNOWN'
         END

         UPDATE ORDERS WITH (ROWLOCK)
         SET UserDefine10 = @c_ParcelType
           , ShipperKey   = @c_ShipperKey
           , EditWho      = SUSER_SNAME()
           , EditDate     = GETDATE()
           , TrafficCop   = NULL
         WHERE OrderKey   = @c_OrderKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg   = ERROR_MESSAGE()
         END

         SET @c_ParcelCategory = ''
         SELECT @c_ParcelCategory = CL.UDF01
         FROM  #TMP_CODELKUP CL
         WHERE CL.ListName  = 'HUSQPKTYPE'
         AND   CL.StorerKey = @c_StorerKey
         AND   CL.Short     = @c_ParcelType

         UPDATE #TMP_ORD
            SET ParcelType     = @c_ParcelType
              , ParcelCategory = @c_ParcelCategory
         WHERE OrderKey = @c_OrderKey

         FETCH NEXT FROM @CUR_ORD INTO @c_OrderKey
      END
      CLOSE @CUR_ORD
      DEALLOCATE @CUR_ORD
   END

   IF @n_Continue = 1
   BEGIN
      SELECT TOP 1 @c_BuildParmLineNo = BPD.BuildParmLineNo
      FROM BUILDPARMDETAIL BPD WITH (NOLOCK)
      WHERE BPD.BuildParmKey = @c_BuildParmKey
      AND   BPD.[Type] = 'CONDITION'
      AND   BPD.FieldName = 'ORDERS.UserDefine10'
      ORDER BY BPD.BuildParmLineNo

      IF @c_SQLMaxOrd <> ''
      BEGIN
         SET @c_SQL = N'UPDATE BUILDPARM WITH (ROWLOCK)'
                    + ' SET EditDate = GETDATE()'
                    + ' ' + @c_SQLMaxOrd
                    + ' WHERE BuildParmKey = @c_BuildParmKey'

         SET @c_SQLParms = N'@c_BuildParmKey NVARCHAR(10)'
                         + ', @n_MaxOrdPerBld INT'

         EXEC SP_EXECUTESQL
               @c_SQL
             , @c_SQLParms
             , @c_BuildParmKey
             , @n_MaxOrdPerBld
      END

      IF @b_Debug = 1
      BEGIN
         SELECT T.ParcelCategory, T.ParcelType, T.DeliveryDate
         FROM #TMP_ORD t
         GROUP BY T.ParcelCategory, T.ParcelType, T.DeliveryDate
         ORDER BY T.ParcelCategory, T.DeliveryDate, T.ParcelType
      END

      SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT T.ParcelCategory, T.DeliveryDate
      FROM #TMP_ORD t
      WHERE T.ParcelCategory <> 'Non-Parcel'
      GROUP BY T.ParcelCategory, T.DeliveryDate
      ORDER BY T.ParcelCategory, T.DeliveryDate

      OPEN @CUR_ORD
      FETCH NEXT FROM @CUR_ORD INTO @c_ParcelCategory, @d_DeliveryDate
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         SET @dt_Date_Fr = @d_DeliveryDate
         SET @dt_Date_To = CONVERT(VARCHAR(10), @d_DeliveryDate, 121) + ' 23:59:59.998'

         SET @c_WaveKey = ''
         SELECT TOP 1 @c_WaveKey = WD.WaveKey
         FROM ORDERS O WITH (NOLOCK)
         JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = O.Orderkey
         JOIN #TMP_CODELKUP CL ON  CL.ListName  = 'HUSQPKTYPE'
                               AND CL.StorerKey = O.StorerKey
                               AND CL.Short     = O.Userdefine10
         WHERE O.StorerKey = @c_StorerKey
         AND   CL.UDF01    = @c_ParcelCategory
         AND   CONVERT(VARCHAR, O.DeliveryDate, 112) = CONVERT(VARCHAR, @d_DeliveryDate, 112)
         GROUP BY WD.WaveKey
         HAVING MIN(O.Status) = '0'
         AND COUNT(1) < @n_MaxOrdPerBld
         ORDER BY WD.WaveKey

         SET @c_ParcelTypes = ''
         ; WITH CS (ParcelType) AS (
         SELECT T.ParcelType
         FROM #TMP_ORD T
         WHERE T.ParcelCategory = @c_ParcelCategory
         AND CONVERT(VARCHAR, T.DeliveryDate, 112) = CONVERT(VARCHAR, @d_DeliveryDate, 112)
         GROUP BY T.ParcelType )
         SELECT @c_ParcelTypes = STRING_AGG ('''' + CS.ParcelType + '''', ',')
         FROM CS

         UPDATE BUILDPARMDETAIL WITH (ROWLOCK)
            SET BuildValue = @c_ParcelTypes -- Use Operator = 'IN'
              , TrafficCop = NULL
         WHERE BuildParmKey  = @c_BuildParmKey
         AND BuildParmLineNo = @c_BuildParmLineNo

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg   = ERROR_MESSAGE()
         END

         IF @b_Debug = 1
         BEGIN
            SELECT @c_WaveKey '@c_WaveKey', @c_BuildParmLineNo '@c_BuildParmLineNo', @d_DeliveryDate '@d_DeliveryDate'
                 , @dt_Date_Fr '@dt_Date_Fr', @dt_Date_To '@dt_Date_To'
                 , @c_ParcelCategory '@c_ParcelCategory', @c_ParcelTypes '@c_ParcelTypes'
            /*
            SELECT BuildParmKey, BuildParmLineNo, Operator, BuildValue FROM BUILDPARMDETAIL WITH (NOLOCK)
            WHERE BuildParmKey  = @c_BuildParmKey AND BuildParmLineNo = @c_BuildParmLineNo

            SELECT DeliveryDate, Userdefine09, Userdefine10, OrderKey, StorerKey
            FROM ORDERS WITH (NOLOCK)
            WHERE OrderKey IN (SELECT OrderKey FROM #TMP_ORD)
            */
         END

         IF @n_Continue = 1
         BEGIN
            SET @c_GenByBuildValue = 'Y'
            EXEC [WM].[lsp_Build_Wave]
                 @c_BuildParmKey   = @c_BuildParmKey
               , @c_Facility       = @c_Facility
               , @c_StorerKey      = @c_StorerKey
               , @c_BuildWaveType  = ''
               , @c_GenByBuildValue= @c_GenByBuildValue
               , @c_SQLBuildWave   = @c_SQLBuildWave OUTPUT
               , @n_BatchNo        = 0
               , @b_Success        = @b_Success      OUTPUT
               , @n_err            = @n_err          OUTPUT
               , @c_ErrMsg         = @c_ErrMsg       OUTPUT
               , @c_UserName       = @c_UserName
               , @dt_Date_Fr       = @dt_Date_Fr
               , @dt_Date_To       = @dt_Date_To
               , @c_WaveKey        = @c_WaveKey

            IF @b_Success = 0
            BEGIN
               SET @n_Continue = 3
            END
         END

         IF @n_Continue = 1
         BEGIN
            UPDATE #TMP_ORD
               SET WaveKey = WD.WaveKey
            FROM #TMP_ORD T
            JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.Orderkey = T.Orderkey
            WHERE ParcelCategory = @c_ParcelCategory

            --IF EXISTS (SELECT 1
            --           FROM #TMP_ORD t
            --           JOIN ORDERS O WITH (NOLOCK) ON O.Orderkey = T.Orderkey
            --           WHERE T.ParcelCategory = @c_ParcelCategory
            --           AND   o.UserDefine09 IN ('', NULL )
            --          )
            --BEGIN
            --   CONTINUE
            --END
         END
         FETCH NEXT FROM @CUR_ORD INTO @c_ParcelCategory, @d_DeliveryDate
      END
      CLOSE @CUR_ORD
      DEALLOCATE @CUR_ORD
   END

   IF @n_Continue = 1
   BEGIN
      IF @b_Debug = 1
      BEGIN
         SELECT T.WaveKey, T.ParcelCategory, T.DeliveryDate
         FROM #TMP_ORD T
         GROUP BY T.WaveKey, T.ParcelCategory, T.DeliveryDate
         ORDER BY T.WaveKey
      END

      SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT T.WaveKey, T.ParcelCategory, T.DeliveryDate
      FROM #TMP_ORD T
      WHERE T.Wavekey <> ''
      GROUP BY T.WaveKey, T.ParcelCategory, T.DeliveryDate
      ORDER BY T.WaveKey

      OPEN @CUR_ORD
      FETCH NEXT FROM @CUR_ORD INTO @c_WaveKey, @c_ParcelCategory, @d_DeliveryDate
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         -- SELECT TOP 1 @d_DeliveryDate = O.DeliveryDate
         -- FROM WAVEDETAIL WD WITH (NOLOCK)
         -- JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey
         -- WHERE WD.WaveKey = @c_WaveKey
         -- ORDER BY WD.WaveDetailKey DESC

         UPDATE WAVE WITH (ROWLOCK)
            SET UserDefine01 = CONVERT(NVARCHAR(19), @d_DeliveryDate, 121)
              , UserDefine02 = @c_ParcelCategory
              , EditWho      = SUSER_SNAME()
              , EditDate     = GETDATE()
              , TrafficCop   = NULL
         WHERE WaveKey = @c_WaveKey

         UPDATE ORDERS WITH (ROWLOCK)
         SET UserDefine03 = 'WaveLock'
         WHERE UserDefine09 = @c_WaveKey
         AND EXISTS (SELECT 1 FROM CODELKUP CL (NOLOCK) WHERE CL.ListName  = 'HUSQPKTYPE'
         AND CL.StorerKey = ORDERS.StorerKey
         AND CL.Short = ORDERS.Userdefine10
         AND UDF03 <> '' AND UDF04 <> '')

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg   = ERROR_MESSAGE()
         END
         FETCH NEXT FROM @CUR_ORD INTO @c_WaveKey, @c_ParcelCategory, @d_DeliveryDate
      END
      CLOSE @CUR_ORD
      DEALLOCATE @CUR_ORD
   END

QUIT_SP:
   IF @n_continue = 3
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
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END

GO