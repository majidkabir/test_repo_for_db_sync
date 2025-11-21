SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_EXG_FilterCondition_UA                          */
/* Creation Date: 01-Jul-2022                                            */
/* Copyright: LFL                                                        */
/* Written by: GuanHao Chan                                              */
/*                                                                       */
/* Purpose: Excel Generator SP FilterCondition for UA.                   */
/*                                                                       */
/* Called By:  ExcelGenerator                                            */
/*                                                                       */
/*                                                                       */
/* Updates:                                                              */
/* Date          Author   Ver  Purposes                                  */
/* 01-Jul-2022   GHChan   1.0  Initial Development                       */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_EXG_FilterCondition_UA] (
   @c_Username       NVARCHAR(200) = ''
 , @n_EXG_Hdr_ID     INT           = 0
 , @c_FileNameFormat NVARCHAR(200) = ''
 , @c_ParamVal1      NVARCHAR(200) = ''
 , @c_ParamVal2      NVARCHAR(200) = ''
 , @c_ParamVal3      NVARCHAR(200) = ''
 , @c_ParamVal4      NVARCHAR(200) = ''
 , @c_ParamVal5      NVARCHAR(200) = ''
 , @c_ParamVal6      NVARCHAR(200) = ''
 , @c_ParamVal7      NVARCHAR(200) = ''
 , @c_ParamVal8      NVARCHAR(200) = ''
 , @c_ParamVal9      NVARCHAR(200) = ''
 , @c_ParamVal10     NVARCHAR(200) = ''
 , @c_FileKeyList    NVARCHAR(500) = '' OUTPUT
 , @b_Debug          INT           = 1
 , @b_Success        INT           = 1 OUTPUT
 , @n_Err            INT           = 0 OUTPUT
 , @c_ErrMsg         NVARCHAR(250) = '' OUTPUT
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

   DECLARE @n_Continue     INT           = 1
         , @n_StartTcnt    INT           = @@TRANCOUNT
         , @n_ITFErr       INT           = 0
         , @c_ITFErrMsg    NVARCHAR(250) = N''
         , @c_FileExt      NVARCHAR(10)  = N''
         , @n_FileKey      INT           = 0
         , @c_TargetFolder NVARCHAR(500) = N''
         , @c_FileName     NVARCHAR(255) = N''
         , @c_Delimiter    NVARCHAR(2)   = N','
         , @b_RetryFlag    BIT           = 0
         , @c_ValidPVal1   NVARCHAR(200) = N''
         , @c_ValidPVal2   NVARCHAR(200) = N''
         , @c_ValidPVal3   NVARCHAR(200) = N''
         , @c_ValidPVal4   NVARCHAR(200) = N''
         , @c_ValidPVal5   NVARCHAR(200) = N''
         , @c_ValidPVal6   NVARCHAR(200) = N''
         , @c_ValidPVal7   NVARCHAR(200) = N''
         , @c_ValidPVal8   NVARCHAR(200) = N''
         , @c_ValidPVal9   NVARCHAR(200) = N''
         , @c_ValidPVal10  NVARCHAR(200) = N'';

   DECLARE @Temp_BatchPVal TABLE (
      [filename] NVARCHAR(255) DEFAULT ''
    , [PVal1]    NVARCHAR(200) DEFAULT ''
    , [PVal2]    NVARCHAR(200) DEFAULT ''
    , [PVal3]    NVARCHAR(200) DEFAULT ''
    , [PVal4]    NVARCHAR(200) DEFAULT ''
    , [PVal5]    NVARCHAR(200) DEFAULT ''
    , [PVal6]    NVARCHAR(200) DEFAULT ''
    , [PVal7]    NVARCHAR(200) DEFAULT ''
    , [PVal8]    NVARCHAR(200) DEFAULT ''
    , [PVal9]    NVARCHAR(200) DEFAULT ''
    , [PVal10]   NVARCHAR(200) DEFAULT ''
   );

   /*********************************************/
   /* Variables Declaration (End)               */
   /*********************************************/

   IF @b_Debug = 1
   BEGIN
      PRINT '[dbo].[isp_EXG_FilterCondition_UA]: Start...';
      PRINT '[dbo].[isp_EXG_FilterCondition_UA]: ' + ' @c_Username=' + ISNULL(RTRIM(@c_Username), '') + ' @n_EXG_Hdr_ID='
            + ISNULL(RTRIM(@n_EXG_Hdr_ID), '') + ',@c_FileNameFormat=' + ISNULL(RTRIM(@c_FileNameFormat), '') + ',@c_ParamVal1='
            + ISNULL(RTRIM(@c_ParamVal1), '') + ',@c_ParamVal2=' + ISNULL(RTRIM(@c_ParamVal2), '') + ',@c_ParamVal3='
            + ISNULL(RTRIM(@c_ParamVal3), '') + ',@c_ParamVal4=' + ISNULL(RTRIM(@c_ParamVal4), '') + ',@c_ParamVal5='
            + ISNULL(RTRIM(@c_ParamVal5), '') + ',@c_ParamVal6=' + ISNULL(RTRIM(@c_ParamVal6), '') + ',@c_ParamVal7='
            + ISNULL(RTRIM(@c_ParamVal7), '') + ',@c_ParamVal8=' + ISNULL(RTRIM(@c_ParamVal8), '') + ',@c_ParamVal9='
            + ISNULL(RTRIM(@c_ParamVal9), '') + ',@c_ParamVal10=' + ISNULL(RTRIM(@c_ParamVal10), '');
   END;

   IF @n_EXG_Hdr_ID <= 0
   BEGIN
      SET @n_Err = 210001;
      SET @c_ErrMsg = 'Invalid EXG Hdr ID. (isp_EXG_FilterCondition_UA)';
      SET @n_Continue = 3;
      GOTO QUIT;
   END;

   SELECT @c_TargetFolder = TargetFolder
        , @c_FileExt      = FileExtension
        , @c_Delimiter    = Delimiter
        , @b_RetryFlag    = RetryFlag
   FROM [GTApps].[dbo].[EXG_Hdr] WITH (NOLOCK)
   WHERE EXG_Hdr_ID = @n_EXG_Hdr_ID;

   BEGIN TRAN;
   BEGIN TRY
      /*******************Construct FileName START******************/
      IF (ISNULL(RTRIM(@c_ParamVal1), '') = '')
      BEGIN
         SET @n_Err = 210002;
         SET @c_ErrMsg = ' StorerKey cannot be null. - (isp_EXG_FilterCondition_UA)';

         IF @b_Debug = 1
         BEGIN
            PRINT '[isp_EXG_FilterCondition_UA]: Execute SP Name Failed...' + ' @c_ErrMsg=' + @c_ErrMsg;
         END;
         GOTO QUIT;
      END;
      IF (ISNULL(RTRIM(@c_ParamVal10), '') = '')
      BEGIN
         SET @n_Err = 210003;
         SET @c_ErrMsg = ' ParamVal10(TransmitlogKey) cannot be null. - (isp_EXG_FilterCondition_UA)';

         IF @b_Debug = 1
         BEGIN
            PRINT '[isp_EXG_FilterCondition_UA]: Execute SP Name Failed...' + ' @c_ErrMsg=' + @c_ErrMsg;
         END;
         GOTO QUIT;
      END;

      IF EXISTS (
      SELECT 1
      FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
      WHERE transmitlogkey = @c_ParamVal10
      )
      BEGIN
         SELECT @c_ParamVal2 = key1
         FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
         WHERE transmitlogkey = @c_ParamVal10;

         IF EXISTS (
         SELECT 1
         FROM dbo.ORDERS           O WITH (NOLOCK)
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK)
         ON O.OrderKey    = PH.OrderKey
         INNER JOIN dbo.PackDetail PD WITH (NOLOCK)
         ON PH.PickSlipNo = PD.PickSlipNo
         INNER JOIN dbo.SKU        S WITH (NOLOCK)
         ON  PD.SKU        = S.Sku
         AND PD.StorerKey = S.StorerKey
         LEFT JOIN dbo.CartonTrack CT WITH (NOLOCK)
         ON  PD.LabelNo    = CT.LabelNo
         AND CT.KeyName   = @c_ParamVal1
         WHERE O.OrderKey = @c_ParamVal2
         )
         BEGIN
            INSERT INTO @Temp_BatchPVal
            (
               [filename]
             , [PVal1]
             , [PVal2]
             , [PVal3]
             , [PVal4]
             , [PVal5]
            )
            SELECT CONCAT(RTRIM(O.ConsigneeKey), '_', RTRIM(O.ExternOrderKey), @c_FileExt)
                 , @c_ParamVal1
                 , @c_ParamVal2
                 , O.ConsigneeKey
                 , O.ExternOrderKey
                 , @c_ParamVal10
            FROM dbo.ORDERS           O WITH (NOLOCK)
            INNER JOIN dbo.PackHeader PH WITH (NOLOCK)
            ON O.OrderKey    = PH.OrderKey
            INNER JOIN dbo.PackDetail PD WITH (NOLOCK)
            ON PH.PickSlipNo = PD.PickSlipNo
            INNER JOIN dbo.SKU        S WITH (NOLOCK)
            ON  PD.SKU        = S.Sku
            AND PD.StorerKey = S.StorerKey
            LEFT JOIN dbo.CartonTrack CT WITH (NOLOCK)
            ON  PD.LabelNo    = CT.LabelNo
            AND CT.KeyName   = @c_ParamVal1
            WHERE O.OrderKey = @c_ParamVal2
            GROUP BY O.ConsigneeKey
                   , O.ExternOrderKey;

            UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
            SET transmitflag = '1'
            WHERE transmitlogkey = @c_ParamVal10;
         END;

      END;
      /*******************Construct FileName END******************/

      STARTCURSOR:

      DECLARE C_FILEKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT [filename]
           , [PVal1]
           , [PVal2]
           , [PVal3]
           , [PVal4]
           , [PVal5]
           , [PVal6]
           , [PVal7]
           , [PVal8]
           , [PVal9]
           , [PVal10]
      FROM @Temp_BatchPVal;

      OPEN C_FILEKEY;
      FETCH NEXT FROM C_FILEKEY
      INTO @c_FileName
         , @c_ValidPVal1
         , @c_ValidPVal2
         , @c_ValidPVal3
         , @c_ValidPVal4
         , @c_ValidPVal5
         , @c_ValidPVal6
         , @c_ValidPVal7
         , @c_ValidPVal8
         , @c_ValidPVal9
         , @c_ValidPVal10;
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         INSERT INTO [dbo].[EXG_FileHdr]
         (
            EXG_Hdr_ID
          , [TargetFolder]
          , [filename]
          , [status]
          , ParamVal1
          , ParamVal2
          , ParamVal3
          , ParamVal4
          , ParamVal5
          , ParamVal6
          , ParamVal7
          , ParamVal8
          , ParamVal9
          , ParamVal10
          , Delimiter
          , RetryFlag
          , AddWho
          , EditWho
         )
         VALUES
         (
            @n_EXG_Hdr_ID
          , @c_TargetFolder
          , @c_FileName
          , 'W'
          , @c_ValidPVal1
          , @c_ValidPVal2
          , @c_ValidPVal3
          , @c_ValidPVal4
          , @c_ValidPVal5
          , @c_ValidPVal6
          , @c_ValidPVal7
          , @c_ValidPVal8
          , @c_ValidPVal9
          , @c_ValidPVal10
          , @c_Delimiter
          , @b_RetryFlag
          , @c_Username
          , @c_Username
         );

         SELECT @n_FileKey = SCOPE_IDENTITY();

         SET @c_FileKeyList += CONVERT(NVARCHAR(10), @n_FileKey);

         --UPDATE [dbo].[EXG_FileHdr] WITH (ROWLOCK)
         --SET [filename] = CONCAT(@c_ParamVal1, '_', @c_ValidPVal4, '_', @c_ValidPVal5, '_', @n_FileKey, @c_FileExt)
         --WHERE file_key = @n_FileKey;

         FETCH NEXT FROM C_FILEKEY
         INTO @c_FileName
            , @c_ValidPVal1
            , @c_ValidPVal2
            , @c_ValidPVal3
            , @c_ValidPVal4
            , @c_ValidPVal5
            , @c_ValidPVal6
            , @c_ValidPVal7
            , @c_ValidPVal8
            , @c_ValidPVal9
            , @c_ValidPVal10;

         IF @@FETCH_STATUS <> -1
         BEGIN
            SET @c_FileKeyList += ', ';
         END;
      END;
      CLOSE C_FILEKEY;
      DEALLOCATE C_FILEKEY;

   END TRY
   BEGIN CATCH
      WHILE @@TRANCOUNT > 0
      ROLLBACK TRAN;

      SELECT @n_ITFErr    = ERROR_NUMBER()
           , @c_ITFErrMsg = ERROR_MESSAGE();

      SET @n_Err = @n_ITFErr;
      SET @c_ErrMsg = LTRIM(RTRIM(@c_ITFErrMsg)) + ' (isp_EXG_FilterCondition_UA)';

      IF @b_Debug = 1
      BEGIN
         PRINT '[isp_EXG_FilterCondition_UA]: Execute SP Name Failed...' + ' @c_ErrMsg=' + @c_ErrMsg;
      END;
      GOTO QUIT;
   END CATCH;

   QUIT:
   WHILE @@TRANCOUNT > 0
   COMMIT TRAN;

   WHILE @@TRANCOUNT < @n_StartTcnt
   BEGIN TRAN;

   IF @n_Continue = 3 -- Error Occured - Process And Return        
   BEGIN
      SELECT @b_Success = 0;
      IF @@TRANCOUNT > @n_StartTcnt
      BEGIN
         ROLLBACK TRAN;
      END;
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTcnt
         BEGIN
            COMMIT TRAN;
         END;
      END;

      IF @b_Debug = 1
      BEGIN
         PRINT '[dbo].[isp_EXG_FilterCondition_UA]: @c_ErrMsg=' + RTRIM(@c_ErrMsg);
         PRINT '[dbo].[isp_EXG_FilterCondition_UA]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR));
      END;

      RETURN;
   END;
   ELSE
   BEGIN
      IF ISNULL(RTRIM(@c_ErrMsg), '') <> ''
      BEGIN
         SELECT @b_Success = 0;
      END;
      ELSE
      BEGIN
         SELECT @b_Success = 1;
      END;

      WHILE @@TRANCOUNT > @n_StartTcnt
      BEGIN
         COMMIT TRAN;
      END;

      IF @b_Debug = 1
      BEGIN
         PRINT '[dbo].[isp_EXG_FilterCondition_UA]: @c_ErrMsg=' + RTRIM(@c_ErrMsg);
         PRINT '[dbo].[isp_EXG_FilterCondition_UA]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR));
      END;
      RETURN;
   END;
/***********************************************/
/* Std - Error Handling (End)                  */
/***********************************************/
END; --End Procedure

GO