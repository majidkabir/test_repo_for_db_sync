SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_VAS_Launch_Label_01                            */
/* Creation Date: 05-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19376 - AU VAS Launch Label                             */
/*                                                                      */
/* Called By: RDT                                                       */
/*          : Datawindow - r_dw_VAS_Launch_Label_01                     */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 05-Apr-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 20-May-2022  WLChooi  1.1  Bug Fix - Select TOP 1 (WL01)             */
/* 20-May-2022  SYChua   1.2  Fix extend orderlineno field length(SY01) */
/************************************************************************/
CREATE PROC [dbo].[isp_VAS_Launch_Label_01] (
      @c_Storerkey   NVARCHAR(15)
    , @c_LabelNo     NVARCHAR(20)
)
AS

BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt          INT
         , @n_Continue           INT = 1
         , @b_Success            INT
         , @n_Err                INT
         , @c_Errmsg             NVARCHAR(255)
         --, @c_OrderLineNo        NVARCHAR(10)   --WL01
         , @c_OrderLineNo        NVARCHAR(20)   --SY01
         , @c_Notes              NVARCHAR(4000)
         , @c_L29                NVARCHAR(500)
         , @n_SeqNo              INT
         , @c_ColValue           NVARCHAR(500)
         , @n_Count              INT

   CREATE TABLE #TMP_VAS (
      --OrderLineNo       NVARCHAR(10)   --WL01
      OrderLineNo       NVARCHAR(20)   --SY01
    , Notes             NVARCHAR(4000)
    , L29               NVARCHAR(500) NULL
    , TitleLine1        NVARCHAR(250)
    , TitleLine2        NVARCHAR(250)
   )

   --Initializing Data
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      INSERT INTO #TMP_VAS(OrderLineNo, Notes, TitleLine1, TitleLine2)
      SELECT TOP 1 OD.ExternLineNo, OD.Notes   --WL01
                 , 'DO NOT DISPLAY'
                 , 'BEFORE'
      FROM PACKDETAIL PD (NOLOCK)
      JOIN PACKHEADER PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey AND OD.StorerKey = PD.StorerKey AND OD.SKU = PD.SKU
      JOIN SKU S (NOLOCK) ON PD.SKU = S.SKU AND PD.StorerKey = S.StorerKey
      WHERE PD.LabelNo = @c_LabelNo
      AND PD.StorerKey = @c_Storerkey

      --INSERT INTO #TMP_VAS(OrderLineNo, Notes)
      --SELECT '900002', '00002', 'S~G01~00002~LFLAUS|L~L04~900002~84704548|L~L06~00002~53.00|L~L08~00002~9503|L~L09~00002~1234|L~L16~00002~050|L~L29~00001~01012022'
   END

   --Main Process
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TV.OrderLineNo, TV.Notes
      FROM #TMP_VAS TV

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_OrderLineNo, @c_Notes

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_L29 = ''

         DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT FDS.SeqNo, FDS.ColValue
         FROM dbo.fnc_DelimSplit('|', @c_Notes) FDS

         OPEN CUR_SPLIT

         FETCH NEXT FROM CUR_SPLIT INTO @n_SeqNo, @c_ColValue

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @c_ColValue LIKE 'L~L29%'   --L~L29~00001~01012022
            BEGIN
               IF EXISTS ( SELECT COUNT(1)
                           FROM dbo.fnc_DelimSplit('~', @c_ColValue)
                           WHERE ColValue LIKE @c_OrderLineNo + '%'   --WL01
                           AND SeqNo = 3)
               BEGIN
                  SELECT @c_L29 = ColValue
                  FROM dbo.fnc_DelimSplit('~', @c_ColValue)
                  WHERE SeqNo = 4

                  IF LEN(TRIM(@c_L29)) = 8
                  BEGIN
                     --Convert to YYYYMMDD then convery to DD.MM.YYYY
                     SET @c_L29 = RIGHT(TRIM(@c_L29), 4) + SUBSTRING(TRIM(@c_L29), 1, 2) + LEFT(TRIM(@c_L29), 2)
                     SET @c_L29 = CONVERT(NVARCHAR(10), CAST(@c_L29 AS DATETIME), 104)
                  END
               END
            END

            FETCH NEXT FROM CUR_SPLIT INTO @n_SeqNo, @c_ColValue
         END
         CLOSE CUR_SPLIT
         DEALLOCATE CUR_SPLIT

         UPDATE #TMP_VAS
         SET L29 = @c_L29
         WHERE OrderLineNo = @c_OrderLineNo

         FETCH NEXT FROM CUR_LOOP INTO @c_OrderLineNo, @c_Notes
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   --Output Result back to DW
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT TV.OrderLineNo
           , TV.Notes
           , TV.L29
           , TV.TitleLine1
           , TV.TitleLine2
      FROM #TMP_VAS TV
      WHERE TRIM(L29) <> ''
      ORDER BY TV.OrderLineNo
   END

   --Clean up - Drop Temp table & Close, Deallocate Cursor
   IF OBJECT_ID('tempdb..#TMP_VAS') IS NOT NULL
      DROP TABLE #TMP_VAS

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_SPLIT') IN (0 , 1)
   BEGIN
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT
   END
END

GO