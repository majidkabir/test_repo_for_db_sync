SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_VAS_Price_Label_01                             */
/* Creation Date: 05-Apr-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19348 - AU VAS Price Label                              */
/*                                                                      */
/* Called By: RDT                                                       */
/*          : Datawindow - r_dw_VAS_Price_Label_01                      */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 05-Apr-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 24-Aug-2022  SYChua   1.1  JSM-90848 Fix multi line same sku orders  */
/*                            printing multiples of same label (SY01)   */
/************************************************************************/
CREATE PROC [dbo].[isp_VAS_Price_Label_01] (
      @c_Storerkey   NVARCHAR(15)
    , @c_LabelNo     NVARCHAR(20)
    , @c_SKU         NVARCHAR(20)
    , @n_Qty         INT = 1
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
         , @c_ExternLineNo       NVARCHAR(20)
         , @c_OrderLineNo        NVARCHAR(5)
         , @c_Notes              NVARCHAR(4000)
         , @c_EAN                NVARCHAR(20)
         , @c_L04                NVARCHAR(500)
         , @c_L06                NVARCHAR(500)
         , @c_L09                NVARCHAR(500)
         , @n_SeqNo              INT
         , @c_ColValue           NVARCHAR(500)
         , @n_Count              INT

   CREATE TABLE #TMP_VAS (
      ExternLineNo      NVARCHAR(20)
    , OrderLineNo       NVARCHAR(5)
    , Notes             NVARCHAR(4000)
    , EAN               NVARCHAR(20)
    , L04               NVARCHAR(500) NULL
    , L06               NVARCHAR(500) NULL
    , L09               NVARCHAR(500) NULL
   )

   --Initializing Data
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      INSERT INTO #TMP_VAS(ExternLineNo, OrderLineNo, Notes, EAN)
      SELECT DISTINCT OD.ExternLineNo, OD.OrderLineNumber, OD.Notes, S.MANUFACTURERSKU
      FROM PACKDETAIL PD (NOLOCK)
      JOIN PACKHEADER PH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey AND OD.StorerKey = PD.StorerKey AND OD.SKU = PD.SKU
      JOIN SKU S (NOLOCK) ON PD.SKU = S.SKU AND PD.StorerKey = S.StorerKey
      WHERE PD.LabelNo = @c_LabelNo
      AND PD.StorerKey = @c_Storerkey
      AND S.MANUFACTURERSKU = @c_SKU

      --INSERT INTO #TMP_VAS(ExternLineNo, OrderLineNo, Notes, EAN)
      --SELECT '900002', '00002', 'S~G01~00002~LFLAUS|L~L04~900002~84704548|L~L06~00002~53.00|L~L08~00002~9503|L~L09~00002~1234|L~L16~00002~050', '9501101530004'
   END

   --Main Process
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TV.ExternLineNo, TV.OrderLineNo, TV.Notes, TV.EAN
      FROM #TMP_VAS TV

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_ExternLineNo, @c_OrderLineNo, @c_Notes, @c_EAN

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_L04 = ''
         SET @c_L06 = ''
         SET @c_L09 = ''

         DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT FDS.SeqNo, FDS.ColValue
         FROM dbo.fnc_DelimSplit('|', @c_Notes) FDS

         OPEN CUR_SPLIT

         FETCH NEXT FROM CUR_SPLIT INTO @n_SeqNo, @c_ColValue

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @c_ColValue LIKE 'L~L04%'   --L~L04~900001~84706246
            BEGIN
               IF EXISTS ( SELECT COUNT(1)
                           FROM dbo.fnc_DelimSplit('~', @c_ColValue)
                           WHERE ColValue = @c_ExternLineNo
                           AND SeqNo = 3)
               BEGIN
                  SELECT @c_L04 = ColValue
                  FROM dbo.fnc_DelimSplit('~', @c_ColValue)
                  WHERE SeqNo = 4
               END
            END
            ELSE IF @c_ColValue LIKE 'L~L06%'   --L~L06~00001~50.00
            BEGIN
               IF EXISTS ( SELECT COUNT(1)
                           FROM dbo.fnc_DelimSplit('~', @c_ColValue)
                           WHERE ColValue = @c_OrderLineNo
                           AND SeqNo = 3)
               BEGIN
                  SELECT @c_L06 = '$' + ColValue
                  FROM dbo.fnc_DelimSplit('~', @c_ColValue)
                  WHERE SeqNo = 4
               END
            END
            ELSE IF @c_ColValue LIKE 'L~L09%'   --L~L09~00001~2626
            BEGIN
               IF EXISTS ( SELECT COUNT(1)
                           FROM dbo.fnc_DelimSplit('~', @c_ColValue)
                           WHERE ColValue = @c_OrderLineNo
                           AND SeqNo = 3)
               BEGIN
                  SELECT @c_L09 = ColValue
                  FROM dbo.fnc_DelimSplit('~', @c_ColValue)
                  WHERE SeqNo = 4
               END
            END

            FETCH NEXT FROM CUR_SPLIT INTO @n_SeqNo, @c_ColValue
         END
         CLOSE CUR_SPLIT
         DEALLOCATE CUR_SPLIT

         --SY01 START (DONT INSERT TABLE IF ALREADY EXISTS SAME LABEL INFORMATION)
         IF EXISTS (SELECT TOP 1 1 FROM #TMP_VAS
                    WHERE L04 = @c_L04
                      AND L06 = @c_L06
                      AND L09 = @c_L09
                      AND EAN = @c_EAN
                      AND ExternLineNo <> @c_ExternLineNo
                      AND OrderLineNo <> @c_OrderLineNo)
         BEGIN
            SET @c_L04 = ''
            SET @c_L06 = ''
            SET @c_L09 = ''
         END
         --SY01 END

         UPDATE #TMP_VAS
         SET L04 = @c_L04
           , L06 = @c_L06
           , L09 = @c_L09
         WHERE ExternLineNo = @c_ExternLineNo
         AND OrderLineNo = @c_OrderLineNo
         AND EAN = @c_EAN

         FETCH NEXT FROM CUR_LOOP INTO @c_ExternLineNo, @c_OrderLineNo, @c_Notes, @c_EAN
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      --Loop No of Copy
      IF (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         SET @n_Count = @n_Qty

         WHILE (@n_Count > 1)
         BEGIN
            INSERT INTO #TMP_VAS(ExternLineNo, OrderLineNo, Notes, EAN, L04, L06, L09)
            SELECT DISTINCT
                   TV.ExternLineNo
                 , TV.OrderLineNo
                 , TV.Notes
                 , TV.EAN
                 , TV.L04
                 , TV.L06
                 , TV.L09
            FROM #TMP_VAS TV
            WHERE CONCAT(TRIM(L04), TRIM(L06), TRIM(L09)) <> ''
            ORDER BY TV.OrderLineNo

            SET @n_Count = @n_Count - 1
         END
      END
   END

   --Output Result back to DW
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT TV.ExternLineNo
           , TV.OrderLineNo
           , TV.Notes
           , TV.EAN
           , TV.L04
           , TV.L06
           , TV.L09
      FROM #TMP_VAS TV
      WHERE CONCAT(TRIM(L04), TRIM(L06), TRIM(L09)) <> ''
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