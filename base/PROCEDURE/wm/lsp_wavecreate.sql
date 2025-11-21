SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: lsp_WaveCreate                                      */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-1790 - SPs for Wave Release Screen -                   */
/*          ( Wave Creation Tab - HomeScreen )                          */
/*                                                                      */
/* Called By: SCE                                                       */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch             */
/* 2021-02-15  Wan01    1.1   MOve Up to Include in Begin try/catch     */
/* 2022-08-10  Wan02    1.2   LFWM-3470 - [CN]NIKE_PHC_Wave Release_Add */
/*                            orderdate filter                          */
/* 2022-08-10  Wan02    1.2   DevOps Combine Script                     */
/* 2024-01-04  Wan03    1.3   LFWM-4625 - CLONE - PROD-CNWAVE Release   */
/*                            group search slow and build wave slow     */
/************************************************************************/
CREATE   PROC [WM].[lsp_WaveCreate]
      @c_Facility          NVARCHAR(5)
   ,  @c_StorerKey         NVARCHAR(15)
   ,  @c_BuildParmKey      NVARCHAR(10)
   ,  @c_BuildWave         CHAR(1)= 'Y'
   ,  @n_BatchNo           BIGINT = 0        OUTPUT
   ,  @n_SessionNo         BIGINT = 0        OUTPUT
   ,  @b_Success           INT = 1           OUTPUT
   ,  @n_err               INT = 0           OUTPUT
   ,  @c_ErrMsg            NVARCHAR(255)     OUTPUT
   ,  @c_UserName          NVARCHAR(128)  = ''
   ,  @b_Debug             INT            = 0            --2020-07-10
   ,  @dt_Date_Fr          DATETIME       = NULL         --(Wan02)
   ,  @dt_Date_To          DATETIME       = NULL         --(Wan02)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_Continue          INT = 1
         ,  @n_Cnt               INT = 0

         ,  @c_BuildParmGroup    NVARCHAR(30) = ''

         ,  @n_SessionNoInit     BIGINT = 0

         ,  @n_TotalWaveCnt      INT    = 0
         ,  @n_TotalOrderQty     INT    = 0
         ,  @n_TotalOrderCnt     INT    = 0
         ,  @n_TotalCube         DECIMAL(10,3)  = 0.000
         ,  @n_TotalWeight       DECIMAL(10,3)  = 0.000

         ,  @n_SessionWaveCnt    INT    = 0
         ,  @n_SessionOrderQty   INT    = 0
         ,  @n_SessionOrderCnt   INT    = 0
         ,  @n_SessionCube       DECIMAL(10,3)  = 0.000
         ,  @n_SessionWeight     DECIMAL(10,3)  = 0.000

         ,  @c_Wavekey           NVARCHAR(10) = ''
         ,  @c_SQLBuildWave      NVARCHAR(MAX)= ''             --2020-07-10

         ,  @CUR_WAVECREATED     CURSOR

   DECLARE @t_WaveCreated     TABLE
      (     SessioNo          BIGINT      NOT NULL
         ,  BatchNo           BIGINT      NOT NULL
         ,  Wavekey           NVARCHAR(10)   DEFAULT('')
         ,  [Cube]            DECIMAL(10,3)  DEFAULT(0.000)
         ,  [Weight]          DECIMAL(10,3)  DEFAULT(0.000)
         ,  NoOfOrder         FLOAT          DEFAULT(0)
      )

   SET @n_SessionNoInit = @n_SessionNo

   --(mingle01) - START
   BEGIN TRY
      IF @c_BuildWave = 'Y'
      BEGIN
         SELECT @n_Cnt = 1
               ,@c_BuildParmGroup = CFG.ParmGroup
         FROM   BUILDPARMGROUPCFG CFG WITH (NOLOCK)
         JOIN   BUILDPARM BP WITH (NOLOCK) ON (CFG.ParmGroup = BP.ParmGroup)
         WHERE  BP.BuildParmKey = @c_BuildParmKey
         AND    CFG.[Type] = 'BuildWaveParm'
         AND    BP.Active = '1'
         ORDER BY BP.BuildParmKey

         IF @n_Cnt = 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err      = 555601
            SET @c_ErrMsg   = 'NSQL' +CONVERT(CHAR(6), @n_Err) +  ': Invalid Build Wave parameter Key. (lsp_WaveCreate)'
            GOTO EXIT_SP
         END

         EXEC [WM].[lsp_Build_Wave]
               @c_BuildParmKey   = @c_BuildParmKey
            ,  @c_Facility       = @c_Facility
            ,  @c_StorerKey      = @c_StorerKey
            ,  @c_BuildWaveType  = ''
            ,  @c_SQLBuildWave   = @c_SQLBuildWave OUTPUT
            ,  @n_BatchNo        = @n_BatchNo      OUTPUT
            ,  @n_SessionNo      = @n_SessionNo    OUTPUT
            ,  @b_Success        = @b_Success      OUTPUT
            ,  @n_err            = @n_err          OUTPUT
            ,  @c_ErrMsg         = @c_ErrMsg       OUTPUT
            ,  @c_UserName       = @c_UserName
            ,  @b_Debug          = @b_Debug                 --2020-07-10
            ,  @dt_Date_Fr       = @dt_Date_Fr              --(Wan02)
            ,  @dt_Date_To       = @dt_Date_To              --(Wan02)

         --2020-07-10 - START
         IF @b_Debug IN (1,2)
         BEGIN
            Print @c_SQLBuildWave
         END
         --2020-07-10 - END

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
         END
      END

      --(Wan01) --MOve Up to Include in Begin try/catch
      IF @n_Continue = 1
      BEGIN
         SET @CUR_WAVECREATED = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT BatchNo = BWL.BatchNo
            ,   Wavekey = BWLD.Wavekey
            ,   TotalWaveCnt=  BWL.TotalWaveCnt
            ,   TotalCube   = ISNULL(BWLD.TotalCube,0)
            ,   TotalWeight = ISNULL(BWLD.TotalWeight,0)
            ,   TotalOrderQty= ISNULL(BWLD.TotalOrderQty,0)
            ,   TotalOrderCnt= ISNULL(BWLD.TotalOrderCnt,0)
         --FROM BUILDWAVELOG BWL WITH (NOLOCK)                                                     --(Wan03)
         --JOIN BUILDWAVEDETAILLOG BWLD WITH (NOLOCK) ON (BWL.BatchNo = BWLD.BatchNo)              --(Wan03)
         --JOIN WAVE WH WITH (NOLOCK) ON BWLD.Wavekey = WH.Wavekey                                 --(Wan03)
         FROM BUILDWAVEDETAILLOG BWLD WITH (NOLOCK)                                                --(Wan03)
         JOIN WAVE WH WITH (NOLOCK) ON WH.Wavekey = BWLD.Wavekey                                   --(Wan03)
         JOIN BUILDWAVELOG BWL WITH (NOLOCK) ON BWL.BatchNo = WH.BatchNo                           --(Wan03)
         WHERE BWL.SessionNo = @n_SessionNo
         --AND BWLD.Wavekey > @c_Wavekey                                                           --(Wan03)
         ORDER BY BWL.BatchNo
                , BWLD.Wavekey

         OPEN @CUR_WAVECREATED

         FETCH NEXT FROM @CUR_WAVECREATED INTO @n_BatchNo
                                             , @c_Wavekey
                                             , @n_TotalWaveCnt
                                             , @n_TotalCube
                                             , @n_TotalWeight
                                             , @n_TotalOrderQty
                                             , @n_TotalOrderCnt

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @n_SessionNoInit = 0
            BEGIN
               SET @n_SessionCube    = @n_SessionCube     + @n_TotalCube
               SET @n_SessionWeight  = @n_SessionWeight   + @n_TotalWeight
               SET @n_SessionOrderQty= @n_SessionOrderQty + @n_TotalOrderQty
               SET @n_SessionOrderCnt= @n_SessionOrderCnt + @n_TotalOrderCnt
               SET @n_SessionWaveCnt = @n_SessionWaveCnt  + 1
            END
            ELSE
            BEGIN
               SET @n_TotalOrderQty = 0
               SET @n_TotalOrderCnt = 0
               SELECT @n_TotalOrderQty = ISNULL(SUM(OH.OpenQty),0)
                    , @n_TotalOrderCnt = COUNT( DISTINCT OH.Orderkey)                              --(Wan03)
               --FROM WAVEDETAIL  WD WITH (NOLOCK)                                                 --(Wan03)
               --JOIN ORDERS OH WITH (NOLOCK) ON (WD.Orderkey= OH.Orderkey)                        --(Wan03)
               --WHERE WD.Wavekey = @c_Wavekey                                                     --(Wan03)
               FROM ORDERS OH WITH (NOLOCK)                                                        --(Wan03)
               WHERE OH.UserDefine09 = @c_Wavekey                                                  --(Wan03)

               SET @n_TotalCube       = 0.00
               SET @n_TotalWeight     = 0.00
               SELECT  @n_TotalCube   = ISNULL(SUM(OD.OpenQty * SKU.StdCube),0)
                     , @n_TotalWeight = ISNULL(SUM(OD.OpenQty * SKU.StdGrossWgt),0)
               FROM WAVEDETAIL  WD WITH (NOLOCK)
               JOIN ORDERDETAIL OD WITH (NOLOCK) ON (WD.Orderkey= OD.Orderkey)
               JOIN SKU         WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey)
                                              AND(OD.Sku = SKU.Sku)
               WHERE WD.Wavekey = @c_Wavekey

               SET @n_SessionCube    = @n_SessionCube    + @n_TotalCube
               SET @n_SessionWeight  = @n_SessionWeight  + @n_TotalWeight
               SET @n_SessionOrderQty= @n_SessionOrderQty+ @n_TotalOrderQty
               SET @n_SessionOrderCnt= @n_SessionOrderCnt+ @n_TotalOrderCnt
               SET @n_SessionWaveCnt = @n_SessionWaveCnt + 1
            END

            INSERT INTO @t_WaveCreated
               (  SessioNo
               ,  BatchNo
               ,  Wavekey
               ,  [Cube]
               ,  [Weight]
               ,  NoOfOrder
               )
            VALUES
               (
                  @n_SessionNo
               ,  @n_BatchNo
               ,  @c_Wavekey
               ,  @n_TotalCube
               ,  @n_TotalWeight
               ,  @n_TotalOrderCnt
               )

            FETCH NEXT FROM @CUR_WAVECREATED INTO @n_BatchNo
                                                , @c_Wavekey
                                                , @n_TotalWaveCnt
                                                , @n_TotalCube
                                                , @n_TotalWeight
                                                , @n_TotalOrderQty
                                                , @n_TotalOrderCnt
         END
         CLOSE @CUR_WAVECREATED
         DEALLOCATE @CUR_WAVECREATED
      END
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP:
   IF @n_Continue = 1
   BEGIN
      --(Wan01) Move Up
      --SET @CUR_WAVECREATED = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --SELECT BatchNo = BWL.BatchNo
      --   ,   Wavekey = BWLD.Wavekey
      --   ,   TotalWaveCnt=  BWL.TotalWaveCnt
      --   ,   TotalCube   = ISNULL(BWLD.TotalCube,0)
      --   ,   TotalWeight = ISNULL(BWLD.TotalWeight,0)
      --   ,   TotalOrderQty= ISNULL(BWLD.TotalOrderQty,0)
      --   ,   TotalOrderCnt= ISNULL(BWLD.TotalOrderCnt,0)
      --FROM BUILDWAVELOG BWL WITH (NOLOCK)
      --JOIN BUILDWAVEDETAILLOG BWLD WITH (NOLOCK) ON (BWL.BatchNo = BWLD.BatchNo)
      --JOIN WAVE WH WITH (NOLOCK) ON BWLD.Wavekey = WH.Wavekey
      --WHERE BWL.SessionNo = @n_SessionNo
      --AND BWLD.Wavekey > @c_Wavekey
      --ORDER BY BWL.BatchNo
      --       , BWLD.Wavekey

      --OPEN @CUR_WAVECREATED

      --FETCH NEXT FROM @CUR_WAVECREATED INTO @n_BatchNo
      --                                    , @c_Wavekey
      --                                    , @n_TotalWaveCnt
      --                                    , @n_TotalCube
      --                                    , @n_TotalWeight
      --                                    , @n_TotalOrderQty
      --                                    , @n_TotalOrderCnt

      --WHILE @@FETCH_STATUS <> -1
      --BEGIN
      --   IF @n_SessionNoInit = 0
      --   BEGIN
      --      SET @n_SessionCube    = @n_SessionCube     + @n_TotalCube
      --      SET @n_SessionWeight  = @n_SessionWeight   + @n_TotalWeight
      --      SET @n_SessionOrderQty= @n_SessionOrderQty + @n_TotalOrderQty
      --      SET @n_SessionOrderCnt= @n_SessionOrderCnt + @n_TotalOrderCnt
      --      SET @n_SessionWaveCnt = @n_SessionWaveCnt  + 1
      --   END
      --   ELSE
      --   BEGIN
      --      SET @n_TotalOrderQty = 0
      --      SET @n_TotalOrderCnt = 0
      --      SELECT @n_TotalOrderQty = ISNULL(SUM(OH.OpenQty),0)
      --           , @n_TotalOrderCnt = COUNT( DISTINCT WD.Orderkey)
      --      FROM WAVEDETAIL  WD WITH (NOLOCK)
      --      JOIN ORDERS OH WITH (NOLOCK) ON (WD.Orderkey= OH.Orderkey)
      --      WHERE WD.Wavekey = @c_Wavekey

      --      SET @n_TotalCube       = 0.00
      --      SET @n_TotalWeight     = 0.00
      --      SELECT  @n_TotalCube   = ISNULL(SUM(OD.OpenQty * SKU.StdCube),0)
      --            , @n_TotalWeight = ISNULL(SUM(OD.OpenQty * SKU.StdGrossWgt),0)
      --      FROM WAVEDETAIL  WD WITH (NOLOCK)
      --      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (WD.Orderkey= OD.Orderkey)
      --      JOIN SKU         WITH (NOLOCK) ON (OD.Storerkey = SKU.Storerkey)
      --                                     AND(OD.Sku = SKU.Sku)
      --      WHERE WD.Wavekey = @c_Wavekey

      --      SET @n_SessionCube    = @n_SessionCube    + @n_TotalCube
      --      SET @n_SessionWeight  = @n_SessionWeight  + @n_TotalWeight
      --      SET @n_SessionOrderQty= @n_SessionOrderQty+ @n_TotalOrderQty
      --      SET @n_SessionOrderCnt= @n_SessionOrderCnt+ @n_TotalOrderCnt
      --      SET @n_SessionWaveCnt = @n_SessionWaveCnt + 1
      --   END

      --   INSERT INTO @t_WaveCreated
      --      (  SessioNo
      --      ,  BatchNo
      --      ,  Wavekey
      --      ,  [Cube]
      --      ,  [Weight]
      --      ,  NoOfOrder
      --      )
      --   VALUES
      --      (
      --         @n_SessionNo
      --      ,  @n_BatchNo
      --      ,  @c_Wavekey
      --      ,  @n_TotalCube
      --      ,  @n_TotalWeight
      --      ,  @n_TotalOrderCnt
      --      )

      --   FETCH NEXT FROM @CUR_WAVECREATED INTO @n_BatchNo
      --                                       , @c_Wavekey
      --                                       , @n_TotalWaveCnt
      --                                       , @n_TotalCube
      --                                       , @n_TotalWeight
      --                                       , @n_TotalOrderQty
      --                                       , @n_TotalOrderCnt
      --END
      --CLOSE @CUR_WAVECREATED
      --DEALLOCATE @CUR_WAVECREATED

      SELECT SessioNo
         ,  TotalWaveCnt = @n_SessionWaveCnt
         ,  TotalCube    = @n_SessionCube
         ,  TotalWeight  = @n_SessionWeight
         ,  TotalOrderQty= @n_SessionOrderQty
         ,  TotalOrderCnt= @n_SessionOrderCnt
         ,  BatchNo
         ,  Wavekey
         ,  [Cube]
         ,  [Weight]
         ,  NoOfOrder
      FROM @t_WaveCreated
   END
END

GO