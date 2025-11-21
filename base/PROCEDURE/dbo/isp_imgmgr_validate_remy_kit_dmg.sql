SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_ImgMgr_Validate_Remy_KIT_DMG                    */
/* Creation Date: 04-Aug-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: GuanHaoChan                                              */
/*                                                                      */
/* Purpose: Fields Validation for Image Manager Remy Kit Damage         */
/*                                                                      */
/* Input Parameters:  @b_Debug            - 0                           */
/*                    @c_Format           - 'XML/JSON'                  */
/*                    @c_UserID           - 'UserName'                  */
/*                    @c_OperationType    - 'Operation'                 */
/*                    @c_RequestString    - ''                          */
/*                    @b_Debug            - 0                           */
/*                                                                      */
/* Output Parameters: @b_Success          - Success Flag    = 0         */
/*                    @c_ErrNo            - Error No        = 0         */
/*                    @c_ErrMsg           - Error Message   = ''        */
/*                    @c_ResponseString   - ResponseString  = ''        */
/*                                                                      */
/* Called By: ImageProcessor - isp_Generic_WebAPI_Request               */
/*                                                                      */
/* PVCS Version: -                                                      */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Purposes														*/
/* 2021-Aug-04 GHChan   Initial                                         */
/************************************************************************/
CREATE PROC [dbo].[isp_ImgMgr_Validate_Remy_KIT_DMG]
(
    @b_Debug INT = 0,
    @x_xml XML,
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

    DECLARE @n_Continue INT,
            @n_StartCnt INT,
            @c_ExecStatements NVARCHAR(MAX),
            @c_ExecArguments NVARCHAR(2000),
            @n_doc INT,
            @c_col1 NVARCHAR(100),
            @c_col2 NVARCHAR(100),
            @c_col3 NVARCHAR(100),
            @c_col4 NVARCHAR(100),
            @c_col5 NVARCHAR(100),
            @c_col6 NVARCHAR(100),
            @c_col7 NVARCHAR(100),
            @c_col8 NVARCHAR(100),
            @c_col9 NVARCHAR(100),
            @c_col10 NVARCHAR(100),
            @c_col11 NVARCHAR(100),
            @c_col12 NVARCHAR(100),
            @c_col13 NVARCHAR(100),
            @c_col14 NVARCHAR(100),
            @c_col15 NVARCHAR(2000),
            @b_ViewAction BIT,
            @c_ImgName NVARCHAR(100),
            @n_ActionFlag INT,
            @n_RecordID INT,
            @c_StorerKey NVARCHAR(15),
            @c_TableName NVARCHAR(20),
            @c_Key1 NVARCHAR(20),
            @c_Key2 NVARCHAR(20),
            @c_Key3 NVARCHAR(20),
            @n_LineSeq INT,
            @c_Data NVARCHAR(2000),
            @c_ListImageName NVARCHAR(2000);

    --DECLARE @tempJson TABLE
    --(
    --    --RowRef            INT IDENTITY(1,1) NOT NULL
    --    ContainerNumber NVARCHAR(30) NULL,
    --    DefectCode NVARCHAR(50) NULL,
    --    DefectQty NVARCHAR(10) NULL,
    --    Remarks NVARCHAR(2000) NULL,
    --    ImageName NVARCHAR(100) NULL
    --);

    DECLARE @tempJson TABLE
    (
        --RowRef            INT IDENTITY(1,1) NOT NULL
        col1 NVARCHAR(100) NULL
            DEFAULT '',
        col2 NVARCHAR(100) NULL
            DEFAULT '',
        col3 NVARCHAR(100) NULL
            DEFAULT '',
        col4 NVARCHAR(100) NULL
            DEFAULT '',
        col5 NVARCHAR(100) NULL
            DEFAULT '',
        col6 NVARCHAR(100) NULL
            DEFAULT '',
        col7 NVARCHAR(100) NULL
            DEFAULT '',
        col8 NVARCHAR(100) NULL
            DEFAULT '',
        col9 NVARCHAR(100) NULL
            DEFAULT '',
        col10 NVARCHAR(100) NULL
            DEFAULT '',
        col11 NVARCHAR(100) NULL
            DEFAULT '',
        col12 NVARCHAR(100) NULL
            DEFAULT '',
        col13 NVARCHAR(100) NULL
            DEFAULT '',
        col14 NVARCHAR(100) NULL
            DEFAULT '',
        col15 NVARCHAR(2000) NULL
            DEFAULT '',
        ImageName NVARCHAR(100) NULL
    );

    SET @n_Continue = 1;
    SET @n_StartCnt = @@TRANCOUNT;
    SET @b_Success = 1;
    SET @n_ErrNo = 0;
    SET @c_ErrMsg = '';

    SET @c_col1 = N'';
    SET @c_col2 = N'';
    SET @c_col3 = N'';
    SET @c_col4 = N'';
    SET @c_col5 = N'';
    SET @c_col6 = N'';
    SET @c_col7 = N'';
    SET @c_col8 = N'';
    SET @c_col9 = N'';
    SET @c_col10 = N'';
    SET @c_col11 = N'';
    SET @c_col12 = N'';
    SET @c_col13 = N'';
    SET @c_col14 = N'';
    SET @c_col15 = N'';

    SET @b_ViewAction = 1;
    SET @c_ImgName = N'';

    SET @n_ActionFlag = 0; -- 1 == INSERT ; 2 == UPDATE

    SET @n_RecordID = 0;
    SET @c_StorerKey = N'';
    SET @c_TableName = N'IMPR_';
    SET @c_Key1 = N'';
    SET @c_Key2 = N'';
    SET @c_Key3 = N'';
    SET @n_LineSeq = 0;
    SET @c_Data = N'';
    SET @c_ListImageName = N'';


    STEP_1:
    IF @n_Continue = 1
    BEGIN
        EXEC sp_xml_preparedocument @n_doc OUTPUT, @x_xml;

        --Read data from XML
        SELECT @c_col1 = ISNULL(RTRIM(col1), ''),
               @c_col2 = ISNULL(RTRIM(col2), ''),
               @c_col3 = ISNULL(RTRIM(col3), ''),
               @c_col4 = ISNULL(RTRIM(col4), ''),
               @c_col5 = ISNULL(RTRIM(col5), ''),
               @c_col6 = ISNULL(RTRIM(col6), ''),
               @c_col7 = ISNULL(RTRIM(col7), ''),
               @c_col8 = ISNULL(RTRIM(col8), ''),
               @c_col9 = ISNULL(RTRIM(col9), ''),
               @c_col10 = ISNULL(RTRIM(col10), ''),
               @c_col11 = ISNULL(RTRIM(col11), ''),
               @c_col12 = ISNULL(RTRIM(col12), ''),
               @c_col13 = ISNULL(RTRIM(col13), ''),
               @c_col14 = ISNULL(RTRIM(col14), ''),
               @c_col15 = ISNULL(RTRIM(col15), ''),
               @b_ViewAction = ViewAction,
               @c_ImgName = ISNULL(RTRIM(ImgName), '')
        FROM
            OPENXML(@n_doc, 'Request/Data', 1)
            WITH
            (
                col1 NVARCHAR(100) 'col1', --StorerKey
                col2 NVARCHAR(100) 'col2', --Type
                col3 NVARCHAR(100) 'col3', --KittingNo
                col4 NVARCHAR(100) 'col4', --SKU
                col5 NVARCHAR(100) 'col5', --Lottable
                col6 NVARCHAR(100) 'col6', --DefectCode
                col7 NVARCHAR(100) 'col7', --ProcessType
                col8 NVARCHAR(100) 'col8',
                col9 NVARCHAR(100) 'col9',
                col10 NVARCHAR(100) 'col10',
                col11 NVARCHAR(100) 'col11',
                col12 NVARCHAR(100) 'col12',
                col13 NVARCHAR(100) 'col13',
                col14 NVARCHAR(100) 'col14',
                col15 NVARCHAR(2000) 'col15',
                ViewAction BIT 'ViewAction',
                ImgName NVARCHAR(100) 'ImgName'
            );

        EXEC sp_xml_removedocument @n_doc;

        IF ISNULL(RTRIM(@c_col3), '') <> ''
        BEGIN

            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.V_KIT WITH (NOLOCK)
                WHERE Remarks = @c_col3
            )
            BEGIN
                SET @n_Continue = 3;
                SET @b_Success = 0;
                SET @n_ErrNo = 10009;
                SET @c_ErrMsg += 'Kitting No. not found!';
            END;
        END;
        IF ISNULL(RTRIM(@c_col4), '') <> ''
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.V_SKU WITH (NOLOCK) WHERE Sku = @c_col4)
            BEGIN
                SET @n_Continue = 3;
                SET @b_Success = 0;
                SET @n_ErrNo = 10009;
                SET @c_ErrMsg += '<br/>SKU not found!';
            END;
        END;
        IF ISNULL(RTRIM(@c_col5), '') <> ''
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.V_SKU WITH (NOLOCK) WHERE Sku = @c_col4)
            BEGIN
                SET @n_Continue = 3;
                SET @b_Success = 0;
                SET @n_ErrNo = 10009;
                SET @c_ErrMsg += '<br/>Lottable Validation SKIPPED!';
            END;
            ELSE
            BEGIN
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.V_CODELKUP WITH (NOLOCK)
                    WHERE LISTNAME = 'IMGMGR'
                          AND Code = 'SKIP_LOT_VALIDATION'
                          AND Storerkey = @c_col1
                          AND UDF01 = @c_col5
                )
                BEGIN
                    IF NOT EXISTS
                    (
                        SELECT 1
                        FROM dbo.V_KITDETAIL WITH (NOLOCK)
                        WHERE StorerKey = @c_col1
                              AND Sku = @c_col4
                              AND LOTTABLE02 = @c_col5
                    )
                    BEGIN
                        SET @n_Continue = 3;
                        SET @b_Success = 0;
                        SET @n_ErrNo = 10009;
                        SET @c_ErrMsg += '<br/>Lottable not found!';
                    END;
                END;
            END;
        END;
        IF ISNULL(RTRIM(@c_col6), '') <> ''
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.CODELKUP WITH (NOLOCK)
                WHERE LISTNAME = 'RMDeteCode'
                      AND Storerkey = @c_col1
                      AND Code = @c_col6
            )
            BEGIN
                SET @n_Continue = 3;
                SET @b_Success = 0;
                SET @n_ErrNo = 10009;
                SET @c_ErrMsg += '<br/>Defect Code not found!';
            END;
        END;
    END;

    QUIT:
    IF @n_Continue = 3 -- Error Occured - Process And Return      
    BEGIN
        SET @b_Success = 0;
        IF @@TRANCOUNT > @n_StartCnt
           AND @@TRANCOUNT = 1
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
        SELECT @b_Success = 1;
        WHILE @@TRANCOUNT > @n_StartCnt
        BEGIN
            COMMIT TRAN;
        END;
        RETURN;
    END;
END; -- Procedure  

GO