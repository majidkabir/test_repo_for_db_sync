SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_ExcelLoader_DocStatusTrack_SubRule1             */
/* Creation Date: 24-May-2021                                            */
/* Copyright: LFL                                                        */
/* Written by: GHChan                                                    */
/*                                                                       */
/* Purpose: Sub rule for DocStatusTrack TABLE.                           */
/*                                                                       */
/* Called By:  Excel Loader                                              */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 24-May-2021 GHChan   1.0  Initial Development                         */
/* 26-Jul-2021 GHChan   1.0  Ticket WMS-17499                            */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_ExcelLoader_DocStatusTrack_SubRule1]
(
    @n_BatchNo INT = 0,
    @n_EIMOpID INT = 0,
    @c_STGTableName NVARCHAR(255) = '',
    @c_POSTTableName NVARCHAR(255) = '',
    @c_PrimaryKey NVARCHAR(1000) = '',
    @c_ActionType CHAR(1) = '',
    @n_Offset INT = 0,
    @n_Limit INT = 0,
    @b_Debug INT = 0,
    @b_Success INT = 0 OUTPUT,
    @n_ErrNo INT = 0 OUTPUT,
    @c_ErrMsg NVARCHAR(250) = '' OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_DEFAULTS OFF;
    SET QUOTED_IDENTIFIER OFF;
    SET CONCAT_NULL_YIELDS_NULL OFF;

    /*********************************************/
    /* Variables Declaration (Start)             */
    /*********************************************/

    DECLARE @n_Continue INT = 1,
            @n_StartCnt INT = 0,
            @c_RecordID BIGINT = 0,
            @c_STG_Status NVARCHAR(1) = N'',
            @c_TableName NVARCHAR(30) = N'',
            @c_DocumentNo NVARCHAR(20) = N'',
            @c_Key1 NVARCHAR(20) = N'',
            @c_Key2 NVARCHAR(20) = N'',
            @c_DocStatus NVARCHAR(10) = N'',
            @c_StorerKey NVARCHAR(15) = N'',
            @c_Facility NVARCHAR(5) = N'',
            @n_RowRef BIGINT = 0,
            @c_Userdefine01 NVARCHAR(30) = N'',
            @c_Userdefine02 NVARCHAR(30) = N'',
            @c_Userdefine03 NVARCHAR(30) = N'',
            @c_Userdefine04 NVARCHAR(30) = N'',
            @c_Userdefine05 NVARCHAR(30) = N'',
            @c_Userdefine06 DATETIME,
            @c_Userdefine07 DATETIME,
            @c_Userdefine08 NVARCHAR(30) = N'',
            @c_Userdefine09 NVARCHAR(30) = N'',
            @c_Userdefine10 NVARCHAR(30) = N'';


    /*********************************************/
    /* Variables Declaration (End)               */
    /*********************************************/
    BEGIN TRANSACTION;


    BEGIN TRY

        BEGIN TRAN;
        SET @b_Success = 1;

        --IF @n_Offset = 0
        --BEGIN

        --   IF EXISTS (SELECT 1 FROM dbo.STG_DocStatusTrack SDST WITH (NOLOCK)
        --              WHERE STG_BatchNo = @n_BatchNo
        --              AND NOT EXISTS(SELECT 1 FROM dbo.DocStatusTrack DST WITH (NOLOCK)
        --                             WHERE DST.TableName = SDST.TableName
        --                             AND DST.DocumentNo = SDST.DocumentNo
        --                             AND DST.Key1 = SDST.Key1
        --                             AND DST.Key2 = SDST.Key2))
        --   BEGIN
        --      SET @b_success = 0
        --      SET @n_Continue = 3
        --      SET @n_ErrNo = 10001   
        --      SET @c_ErrMsg = 'Invalid records! Records not exists in DB! (isp_ExcelLoader_DocStatusTrack_SubRule1)' 

        --      UPDATE dbo.STG_DocStatusTrack WITH (ROWLOCK)
        --      SET STG_Status = '5'
        --         ,STG_ErrMsg = 'Invalid records! Records not exists in DB!'
        --      WHERE STG_BatchNo = @n_BatchNo
        --      AND RecordID IN ( SELECT RecordID 
        --                        FROM dbo.STG_DocStatusTrack SDST WITH (NOLOCK)
        --                        WHERE STG_BatchNo = @n_BatchNo
        --                        AND NOT EXISTS(SELECT 1 FROM dbo.DocStatusTrack DST WITH (NOLOCK)
        --                                       WHERE DST.TableName = SDST.TableName
        --                                       AND DST.DocumentNo = SDST.DocumentNo
        --                                       AND DST.Key1 = SDST.Key1
        --                                       AND DST.Key2 = SDST.Key2))
        --         GOTO QUIT
        --   END
        --END

        DECLARE CUR_UPDSTATUS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT RecordID,
               STG_Status,
               TableName,
               DocumentNo,
               Key1,
               Key2,
               DocStatus,
               Facility,
               StorerKey,
               Userdefine01,
               Userdefine02,
               Userdefine03,
               Userdefine04,
               Userdefine05,
               Userdefine06,
               Userdefine07,
               Userdefine08,
               Userdefine09,
               Userdefine10
        FROM [dbo].[STG_DocStatusTrack] WITH (NOLOCK)
        WHERE STG_BatchNo = @n_BatchNo
        ORDER BY [No] ASC OFFSET @n_Offset ROWS FETCH NEXT @n_Limit ROWS ONLY;

        OPEN CUR_UPDSTATUS;

        FETCH FROM CUR_UPDSTATUS
        INTO @c_RecordID,
             @c_STG_Status,
             @c_TableName,
             @c_DocumentNo,
             @c_Key1,
             @c_Key2,
             @c_DocStatus,
             @c_Facility,
             @c_StorerKey,
             @c_Userdefine01,
             @c_Userdefine02,
             @c_Userdefine03,
             @c_Userdefine04,
             @c_Userdefine05,
             @c_Userdefine06,
             @c_Userdefine07,
             @c_Userdefine08,
             @c_Userdefine09,
             @c_Userdefine10;

        WHILE @@FETCH_STATUS <> -1
        BEGIN
            SET @n_RowRef = 0;
            SELECT @n_RowRef = RowRef
            FROM dbo.DocStatusTrack WITH (NOLOCK)
            WHERE StorerKey = '18467'
                  AND Facility = 'NSH04'
                  AND TableName = @c_TableName
                  AND DocumentNo = @c_DocumentNo
                  AND DocStatus = '1'
                  AND Key1 = @c_Key1
                  AND Key2 = @c_Key2;

            IF @n_RowRef <> 0
            BEGIN
                UPDATE dbo.DocStatusTrack WITH (ROWLOCK)
                SET DocStatus = @c_DocStatus,
                    Userdefine01 = CASE
                                       WHEN @c_Userdefine01 = NULL THEN
                                           Userdefine01
                                       WHEN @c_Userdefine01 = '-' THEN
                                           ''
                                       ELSE
                                           @c_Userdefine01
                                   END,
                    Userdefine02 = CASE
                                       WHEN @c_Userdefine02 = NULL THEN
                                           Userdefine02
                                       WHEN @c_Userdefine02 = '-' THEN
                                           ''
                                       ELSE
                                           @c_Userdefine02
                                   END,
                    Userdefine03 = CASE
                                       WHEN @c_Userdefine03 = NULL THEN
                                           Userdefine03
                                       WHEN @c_Userdefine03 = '-' THEN
                                           ''
                                       ELSE
                                           @c_Userdefine03
                                   END,
                    Userdefine04 = CASE
                                       WHEN @c_Userdefine04 = NULL THEN
                                           Userdefine04
                                       WHEN @c_Userdefine04 = '-' THEN
                                           ''
                                       ELSE
                                           @c_Userdefine04
                                   END,
                    Userdefine05 = CASE
                                       WHEN @c_Userdefine05 = NULL THEN
                                           Userdefine05
                                       WHEN @c_Userdefine05 = '-' THEN
                                           ''
                                       ELSE
                                           @c_Userdefine05
                                   END,
                    Userdefine06 = CASE
                                       WHEN @c_Userdefine06 = NULL THEN
                                           Userdefine06
                                       WHEN @c_Userdefine06 = '-' THEN
                                           ''
                                       ELSE
                                           @c_Userdefine06
                                   END,
                    Userdefine07 = CASE
                                       WHEN @c_Userdefine07 = NULL THEN
                                           Userdefine07
                                       WHEN @c_Userdefine07 = '-' THEN
                                           ''
                                       ELSE
                                           @c_Userdefine07
                                   END,
                    Userdefine08 = CASE
                                       WHEN @c_Userdefine08 = NULL THEN
                                           Userdefine08
                                       WHEN @c_Userdefine08 = '-' THEN
                                           ''
                                       ELSE
                                           @c_Userdefine08
                                   END,
                    Userdefine09 = CASE
                                       WHEN @c_Userdefine09 = NULL THEN
                                           Userdefine09
                                       WHEN @c_Userdefine09 = '-' THEN
                                           ''
                                       ELSE
                                           @c_Userdefine09
                                   END,
                    Userdefine10 = CASE
                                       WHEN @c_Userdefine10 = NULL THEN
                                           Userdefine10
                                       WHEN @c_Userdefine10 = '-' THEN
                                           ''
                                       ELSE
                                           @c_Userdefine10
                                   END
                WHERE RowRef = @n_RowRef;

                UPDATE dbo.STG_DocStatusTrack WITH (ROWLOCK)
                SET STG_Status = '9'
                WHERE RecordID = @c_RecordID;
            END;
            ELSE
            BEGIN
                UPDATE dbo.STG_DocStatusTrack WITH (ROWLOCK)
                SET STG_Status = '5',
                    STG_ErrMsg = 'Invalid records! Records not exists in DB! '
                WHERE RecordID = @c_RecordID;
            END;

            FETCH FROM CUR_UPDSTATUS
            INTO @c_RecordID,
                 @c_STG_Status,
                 @c_TableName,
                 @c_DocumentNo,
                 @c_Key1,
                 @c_Key2,
                 @c_DocStatus,
                 @c_Facility,
                 @c_StorerKey,
                 @c_Userdefine01,
                 @c_Userdefine02,
                 @c_Userdefine03,
                 @c_Userdefine04,
                 @c_Userdefine05,
                 @c_Userdefine06,
                 @c_Userdefine07,
                 @c_Userdefine08,
                 @c_Userdefine09,
                 @c_Userdefine10;
        END;
        CLOSE CUR_UPDSTATUS;
        DEALLOCATE CUR_UPDSTATUS;
    END TRY
    BEGIN CATCH
        --ROLLBACK TRAN
        SET @n_Continue = 3;
        SET @b_Success = 0;
        SET @n_ErrNo = ERROR_NUMBER();
        SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_DocStatusTrack_SubRule1)';
        IF @b_Debug = 1
        BEGIN
            PRINT '[isp_ExcelLoader_DocStatusTrack_SubRule1]: Execute Sub Rule SP Failed...' + ' @c_ErrMsg='
                  + @c_ErrMsg;
        END;
        GOTO QUIT;
    END CATCH;
    QUIT:
    IF @n_Continue = 3 -- Error Occured - Process And Return          
    BEGIN
        SELECT @b_Success = 0;
        IF @@TRANCOUNT = 1
           AND @@TRANCOUNT > @n_StartCnt
        BEGIN
            ROLLBACK TRAN;
        END;
        ELSE
        BEGIN
            WHILE @@TRANCOUNT > @n_StartCnt
            BEGIN
                COMMIT TRAN;
            END;
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

        WHILE @@TRANCOUNT > @n_StartCnt
        BEGIN
            COMMIT TRAN;
        END;
        RETURN;
    END;
END; -- END PROCEDURE 

GO