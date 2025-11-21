SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: isp_WebAPI_PhotoRepoSearch                          */              
/* Creation Date: 05-JAN-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose: Pass Incoming Request String For Interface                  */
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
/* Called By: LeafAPIServer - isp_Generic_WebAPI_Request                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Purposes														*/
/* 2018-12-21  Alex     #CR WMS-5241 - exclude sku search result with   */
/*                         skustatus = suspended. (Alex01)              */
/* 2018-01-15  Alex     #CR WMS-5241 - v2.0 (Alex02)                    */
/************************************************************************/    
CREATE PROC [dbo].[isp_WebAPI_PhotoRepoSearch](
     @b_Debug           INT            = 0
   , @c_Format          VARCHAR(10)    = ''
   , @c_UserID          NVARCHAR(256)  = ''
   , @c_OperationType   NVARCHAR(60)   = ''
   , @c_RequestString   NVARCHAR(MAX)  = ''
   , @b_Success         INT            = 0   OUTPUT
   , @n_ErrNo           INT            = 0   OUTPUT
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT
   , @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT
         , @n_StartCnt                    INT
         , @c_ExecStatements              NVARCHAR(MAX)
         , @c_ExecArguments               NVARCHAR(2000)
         , @x_xml                         XML
         , @n_doc                         INT
         , @c_XMLRequestString            NVARCHAR(MAX)

         , @c_Request_XMLNodes            NVARCHAR(60)
         
         , @b_ServerSideProcess           INT
         , @n_CurrRecordNo                INT
         , @n_TtlSelRecord                INT
         , @c_OrderByOpt                  NVARCHAR(50)

         , @c_SearchType                  NVARCHAR(10)
         , @c_StorerKey                   NVARCHAR(15)
         , @c_SKU                         NVARCHAR(20)
         , @c_DESCR                       NVARCHAR(60)
         , @c_PONumber                    NVARCHAR(18)
         , @c_ContainerNumber             NVARCHAR(30)
         , @c_OrderNumber                 NVARCHAR(10)
         , @c_CustomerName                NVARCHAR(45)

         , @n_CountRecord                 INT
         , @c_DESCR_Condi                 NVARCHAR(62)
         , @c_CustomerName_Condi          NVARCHAR(47)

         , @c_OUT_ContainerNumber         NVARCHAR(45)
         , @c_OUT_SKU                     NVARCHAR(20)

         , @c_WhereClauseCondi            NVARCHAR(500)

         , @c_SKUStsSuspended             NVARCHAR(15)      --(Alex01)

         --(Alex02) - Begin
         , @c_Brand                       NVARCHAR(10)
         , @c_SKUType                     NVARCHAR(10)
         --(Alex02) - End

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT
   SET @b_Success                         = 1
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   SET @c_XMLRequestString                = ''
   
   SET @b_ServerSideProcess               = 0
   SET @n_CurrRecordNo                    = 0
   SET @n_TtlSelRecord                    = 5
   SET @c_OrderByOpt                      = ''

   SET @c_SearchType                      = ''
   SET @c_StorerKey                       = ''
   SET @c_SKU                             = ''
   SET @c_DESCR                           = ''
   SET @c_PONumber                        = ''
   SET @c_ContainerNumber                 = ''
   SET @c_OrderNumber                     = ''
   SET @c_CustomerName                    = ''

   SET @n_CountRecord                     = 0
   SET @c_DESCR_Condi                     = ''
   SET @c_CustomerName_Condi              = ''

   SET @c_OUT_ContainerNumber             = 'TEST0001'
   SET @c_OUT_SKU                         = ''

   SET @c_WhereClauseCondi                = ''

   SET @c_SKUStsSuspended                 = 'SUSPENDED'              --(Alex01)

   --(Alex02) - Begin
   SET @c_Brand                           = ''
   SET @c_SKUType                         = ''
   --(Alex02) - End

   IF ISNULL(RTRIM(@c_RequestString), '') = ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 97001
      SET @c_ErrMsg = 'Content Body cannot be blank.'
      GOTO QUIT
   END

   SET @x_xml = CONVERT(XML, @c_RequestString)

   STEP_1:
   IF @n_Continue = 1
   BEGIN
      EXEC sp_xml_preparedocument @n_doc OUTPUT, @x_xml
      
      --Read data from XML
      SELECT @b_ServerSideProcess = ISNULL(ServerSideProcess, 0)
      , @n_CurrRecordNo = ISNULL(CurrRecordNo, 0)
      , @n_TtlSelRecord = ISNULL(TtlSelRecord, 5)
      , @c_OrderByOpt = ISNULL(RTRIM(OrderByOpt), '')
      , @c_SearchType = ISNULL(RTRIM(SearchType), '')   
      , @c_StorerKey = ISNULL(RTRIM(StorerKey), '')
      , @c_SKU = ISNULL(RTRIM(SKU), '')
      , @c_DESCR = ISNULL(RTRIM([DESCR]), '')
      , @c_PONumber = ISNULL(RTRIM(POKey), '')
      , @c_ContainerNumber = ISNULL(RTRIM(ContainerNumber), '')
      , @c_OrderNumber = ISNULL(RTRIM(OrderKey), '')
      , @c_CustomerName = ISNULL(RTRIM(CustomerName), '')
      --(Alex02) - Begin
      , @c_Brand = ISNULL(RTRIM(Brand), '')
      , @c_SKUType = ISNULL(RTRIM(SKUType), '')
      --(Alex02) - End
      FROM OPENXML (@n_doc, 'Request/Data', 1)
      WITH (
         ServerSideProcess INT            'ServerSideProcess',
         CurrRecordNo      INT            'start',
         TtlSelRecord      INT            'length',
         OrderByOpt        NVARCHAR(50)   'orderby',
         SearchType        NVARCHAR(10)   'SearchType',
         StorerKey         NVARCHAR(15)   'StorerKey',
         SKU               NVARCHAR(20)   'SKU',
         [DESCR]           NVARCHAR(60)   'Description',
         POKey             NVARCHAR(18)   'POKey',
         ContainerNumber   NVARCHAR(30)   'ContainerNumber',
         OrderKey          NVARCHAR(10)   'OrderKey',
         CustomerName      NVARCHAR(45)   'CustomerName',
         Brand             NVARCHAR(10)   'Brand',
         SKUType           NVARCHAR(10)   'SKUType'
      )
      
      EXEC sp_xml_removedocument @n_doc

      IF @c_SearchType NOT IN ('SKU', 'INBOUND', 'OUTBOUND')
      BEGIN
         SET @n_Continue = 3 
         SET @n_ErrNo = 97002
         SET @c_ErrMsg = 'Invalid SearchType[' + @c_SearchType + ']..'
         GOTO QUIT
      END

      IF @c_SearchType = 'SKU'
      BEGIN
         IF @c_SKU = '' AND @c_DESCR = '' AND @c_Brand = ''
         BEGIN
            SET @n_Continue = 3 
            SET @n_ErrNo = 97003
            SET @c_ErrMsg = 'Please fill in at least one fields - (SKU/Description/Brand).'
            GOTO QUIT
         END

         SET @c_DESCR_Condi = '%' + @c_DESCR + '%'
         SET @c_WhereClauseCondi = ' WHERE StorerKey = @c_StorerKey ' 
                                 + IIF(ISNULL(RTRIM(@c_SKU), '') <> '', ' AND SKU = @c_SKU ', '')
                                 + IIF(ISNULL(RTRIM(@c_DESCR), '') <> '', ' AND [DESCR] LIKE @c_DESCR_Condi ', '') 
                                 + IIF(ISNULL(RTRIM(@c_Brand), '') <> '', ' AND [Color] = @c_Brand ', '') 
                                 + IIF(ISNULL(RTRIM(@c_SKUType), '') <> '', ' AND [ItemClass] = @c_SKUType ', '') 
                                 + ' AND SKUStatus <> @c_SKUStsSuspended '

         SET @c_ExecStatements = N'SELECT @n_CountRecord = COUNT(1) '
                               + N'FROM dbo.SKU WITH (NOLOCK) '
                               + @c_WhereClauseCondi

         SET @c_ExecArguments = N'@c_SKU NVARCHAR(20), @c_DESCR_Condi NVARCHAR(62), @c_StorerKey NVARCHAR(15), @c_SKUStsSuspended NVARCHAR(15), '
                              + ' @c_Brand NVARCHAR(10), @c_SKUType NVARCHAR(10), @n_CountRecord INT OUTPUT'

         EXECUTE sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_SKU, @c_DESCR_Condi, @c_StorerKey, @c_SKUStsSuspended, 
         @c_Brand, @c_SKUType, @n_CountRecord OUTPUT

         IF @n_CountRecord = 0
         BEGIN
            SET @n_Continue = 3 
            SET @n_ErrNo = 97004
            SET @c_ErrMsg = 'No SKU records found..'
            GOTO QUIT
         END

         IF @b_ServerSideProcess = 1
         BEGIN
            --SET @c_OUT_SKU = @c_SKU
            SET @c_ExecStatements = N'SELECT @c_ResponseString = ISNULL(RTRIM(( ' + CHAR(13)
                                  + N' SELECT @n_CountRecord As ''TotalRecords'', ( '
                                  + N' SELECT SKU AS ''SKU'', [DESCR] AS ''Description'' ' + CHAR(13)
                                  + N'       , Color AS ''Brand'', CONVERT(NVARCHAR, STDGrossWGT) AS ''Weight'' ' + CHAR(13)
                                  + N'       , CONVERT(NVARCHAR, ISNULL([Length], 0)) + '','' + CONVERT(NVARCHAR, ISNULL([Width], 0)) + '','' + CONVERT(NVARCHAR, ISNULL([Height], 0)) AS ''Dimension'' ' + CHAR(13)
                                  + N' FROM dbo.SKU WITH (NOLOCK) ' + CHAR(13)
                                  + @c_WhereClauseCondi
                                  + N' ORDER BY '
                                  + CASE WHEN ISNULL(RTRIM(@c_OrderByOpt), '') <> '' THEN @c_OrderByOpt ELSE ' SKU ' + CHAR(13) END
                                  + N' OFFSET ' + RTRIM(CONVERT(CHAR, ISNULL(@n_CurrRecordNo, 0))) + CHAR(13) 
                                  + N' ROWS FETCH NEXT ' + RTRIM(CONVERT(CHAR, ISNULL(@n_TtlSelRecord, 10))) + ' ROWS ONLY' 
                                  + N' FOR XML PATH (''Data''), TYPE) ' --, ROOT(''Response'') '
                                  + N' FOR XML PATH(''Response'')'
                                  + N')), '''') '
            SET @c_ExecArguments = N'@c_SKU NVARCHAR(20), @c_DESCR_Condi NVARCHAR(62), @c_StorerKey NVARCHAR(15), @c_SKUStsSuspended NVARCHAR(15), '
                                 + ' @c_Brand NVARCHAR(10), @c_SKUType NVARCHAR(10), @n_CountRecord INT, @c_ResponseString NVARCHAR(MAX) OUTPUT'

            IF @b_Debug = 1
            BEGIN
               PRINT '>>>>>> Generate SKU RESPONSE XML QUERY'
               PRINT @c_ExecStatements
            END

            EXECUTE sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_SKU, @c_DESCR_Condi, @c_StorerKey, @c_SKUStsSuspended, 
               @c_Brand, @c_SKUType, @n_CountRecord, @c_ResponseString OUTPUT
         END
         --SET @c_ResponseString = ISNULL(RTRIM((
         --                           SELECT @c_OUT_ContainerNumber As 'ContainerNumber'
         --                                 ,@c_OUT_SKU As 'SKU'
         --                           FOR XML PATH('Response'))
         --                        ) , '')
      END

      --IF @c_SearchType = 'INBOUND'
      --BEGIN
      --   IF @c_PONumber = '' AND @c_ContainerNumber = ''
      --   BEGIN
      --      SET @n_Continue = 3 
      --      SET @n_ErrNo = 97005
      --      SET @c_ErrMsg = "Please fill in at least one fields - (PONumber/ContainerNumber)."
      --      GOTO QUIT
      --   END

      --   SET @c_ExecStatements = N'SELECT @n_CountRecord = COUNT(1)'
      --                         + ' FROM '
      --                         + ' ( '
      --                         + '     SELECT R.ContainerKey, P.ExternPOKey, P.POKey '
      --                         + '     FROM dbo.RECEIPT R WITH (NOLOCK) '
      --                         + '     INNER JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) '
      --                         + '     ON ( RD.ReceiptKey = R.ReceiptKey AND R.StorerKey = @c_StorerKey '
      --                         + IIF(ISNULL(RTRIM(@c_ContainerNumber), '') <> '', 
      --                           '     AND R.ContainerKey = @c_ContainerNumber ', '')
      --                         + '     ) '
      --                         + '     INNER JOIN dbo.PO P WITH (NOLOCK) '
      --                         + '      ON ( P.POKey = RD.POKey '
      --                         + IIF(ISNULL(RTRIM(@c_PONumber), '') <> '', 
      --                           '      AND (P.POKey = @c_PONumber OR P.ExternPOKey = @c_PONumber) ', '')  
      --                         + '     ) '
      --                         + '     GROUP BY R.ContainerKey, P.ExternPOKey, P.POKey '
      --                         + ' ) a '
         
      --   SET @c_ExecArguments = N'@c_PONumber NVARCHAR(18), @c_ContainerNumber NVARCHAR(30), @c_StorerKey NVARCHAR(15), @n_CountRecord INT OUTPUT'

      --   IF @b_Debug = 1
      --   BEGIN
      --      PRINT '>>>>>> Generate Non SSP - INBOUND RESPONSE XML QUERY'
      --      PRINT @c_ExecStatements
      --   END

      --   EXECUTE sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_PONumber, @c_ContainerNumber, @c_StorerKey, @n_CountRecord OUTPUT

      --   IF @n_CountRecord = 0
      --   BEGIN
      --      SET @n_Continue = 3 
      --      SET @n_ErrNo = 97006
      --      SET @c_ErrMsg = 'No INBOUND records found..'
      --      GOTO QUIT
      --   END

      --   IF @b_ServerSideProcess = 1
      --   BEGIN
      --      SET @c_ExecStatements = N'SELECT @c_ResponseString = ISNULL(RTRIM(( ' + CHAR(13)
      --                            + N'SELECT @n_CountRecord As ''TotalRecords'', ( ' + CHAR(13)
      --                            + N'    SELECT R.ContainerKey As ''ContainerNumber'', P.ExternPOKey As ''ExternPOKey'' '
      --                            + N'       , P.POKey As ''POKey'' ' + CHAR(13)
      --                            + N'    FROM dbo.RECEIPT R WITH (NOLOCK) ' + CHAR(13)
      --                            + N'    INNER JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) ' + CHAR(13)
      --                            + N'    ON ( RD.ReceiptKey = R.ReceiptKey AND R.StorerKey = @c_StorerKey ' + CHAR(13)
      --                            + IIF(ISNULL(RTRIM(@c_ContainerNumber), '') <> '', 
      --                              N'    AND R.ContainerKey = @c_ContainerNumber ', '')
      --                            + N'    ) '
      --                            + N'    INNER JOIN dbo.PO P WITH (NOLOCK) ' + CHAR(13)
      --                            + N'     ON ( P.POKey = RD.POKey ' + CHAR(13)
      --                            + IIF(ISNULL(RTRIM(@c_PONumber), '') <> '', 
      --                              N'     AND (P.POKey = @c_PONumber OR P.ExternPOKey = @c_PONumber) ', '') 
      --                            + N'    ) ' + CHAR(13)
      --                            + N'    GROUP BY R.ContainerKey, P.ExternPOKey, P.POKey ' + CHAR(13)
      --                            + N'    ORDER BY '
      --                            + CASE WHEN ISNULL(RTRIM(@c_OrderByOpt), '') <> '' THEN @c_OrderByOpt ELSE ' P.POKey ' + CHAR(13) END
      --                            + N'    OFFSET ' + RTRIM(CONVERT(CHAR, ISNULL(@n_CurrRecordNo, 0))) + CHAR(13) 
      --                            + N'    ROWS FETCH NEXT ' + RTRIM(CONVERT(CHAR, ISNULL(@n_TtlSelRecord, 10))) + ' ROWS ONLY'  
      --                            + N'    FOR XML PATH (''Data''), TYPE) ' 
      --                            + N' FOR XML PATH(''Response'')'
      --                            + N')), '''') '

      --      SET @c_ExecArguments = N'@c_PONumber NVARCHAR(18), @c_ContainerNumber NVARCHAR(30), @c_StorerKey NVARCHAR(15), @n_CountRecord INT OUTPUT'
      --                           + N', @c_ResponseString NVARCHAR(MAX) OUTPUT'
      --      IF @b_Debug = 1
      --      BEGIN
      --         PRINT '>>>>>> Generate INBOUND RESPONSE XML QUERY'
      --         PRINT @c_ExecStatements
      --      END

      --      EXECUTE sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_PONumber, @c_ContainerNumber, @c_StorerKey, @n_CountRecord OUTPUT
      --                          , @c_ResponseString OUTPUT

      --   END
      --END

      --IF @c_SearchType = 'OUTBOUND'
      --BEGIN
      --   IF @c_OrderNumber = '' AND @c_ContainerNumber = '' AND @c_CustomerName = ''
      --   BEGIN
      --      SET @n_Continue = 3 
      --      SET @n_ErrNo = 97007
      --      SET @c_ErrMsg = "Please fill in at least one fields - (OrderNumber/ContainerNumber/CustomerName)."
      --      GOTO QUIT
      --   END

      --   SET @c_CustomerName_Condi = '%' + @c_CustomerName + '%'
      --   SET @c_WhereClauseCondi = N' WHERE '
      --                           + IIF(ISNULL(RTRIM(@c_OrderNumber), '') <> '', 
      --                             N' ( OH.OrderKey = @c_OrderNumber OR OH.ExternOrderKey = @c_OrderNumber ) ', '')
      --                           + IIF(ISNULL(RTRIM(@c_OrderNumber), '') <> '' AND ISNULL(RTRIM(@c_CustomerName), '') <> '', 'AND', '')
      --                           + IIF(ISNULL(RTRIM(@c_CustomerName), '') <> '', ' OH.C_Company LIKE @c_CustomerName_Condi ', '') 
      --                           + IIF(ISNULL(RTRIM(@c_ContainerNumber), '') <> '' 
      --                              AND (ISNULL(RTRIM(@c_OrderNumber), '') <> '' OR ISNULL(RTRIM(@c_CustomerName), '') <> ''), 'AND', '')
      --                           + IIF(ISNULL(RTRIM(@c_ContainerNumber), '') <> '', 
      --                             N' CONT.ExternContainerKey = @c_ContainerNumber ', '') 
      --                           + N' AND OH.StorerKey = @c_StorerKey '

      --   SET @c_ExecStatements = N'SELECT @n_CountRecord = COUNT(1) '
      --                         + N'FROM dbo.ORDERS OH WITH (NOLOCK) '
      --                         + N'INNER JOIN dbo.CONTAINER CONT WITH (NOLOCK) '
      --                         + N'ON (CONT.Mbolkey = OH.Mbolkey AND ISNULL(RTRIM(CONT.ExternContainerKey), '''') <> '''' ) '
      --                         + @c_WhereClauseCondi

      --   SET @c_ExecArguments = N'@c_OrderNumber NVARCHAR(10), @c_CustomerName_Condi NVARCHAR(47), @c_ContainerNumber NVARCHAR(30), '
      --                        + N'@c_StorerKey NVARCHAR(15), @n_CountRecord INT OUTPUT'
         
      --   IF @b_Debug = 1
      --   BEGIN
      --      PRINT '>>>>>> Generate Non SSP - OUTBOUND RESPONSE XML QUERY'
      --      PRINT @c_ExecStatements
      --   END

      --   EXECUTE sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_OrderNumber, @c_CustomerName_Condi, @c_ContainerNumber, @c_StorerKey, @n_CountRecord OUTPUT

      --   IF @n_CountRecord = 0
      --   BEGIN
      --      SET @n_Continue = 3 
      --      SET @n_ErrNo = 97008
      --      SET @c_ErrMsg = 'No OUTBOUND records found..'
      --      GOTO QUIT
      --   END

      --   IF @b_ServerSideProcess = 1
      --   BEGIN
      --      SET @c_ExecStatements = N'SELECT @c_ResponseString = ISNULL(RTRIM(( ' + CHAR(13)
      --                            + N' SELECT @n_CountRecord As ''TotalRecords'', ( '
      --                            + N' SELECT OH.OrderKey As ''OrderKey'', CONT.ExternContainerKey As ''ContainerNumber'' ' + CHAR(13)
      --                            + N' , OH.ExternOrderKey As ''ExternOrderKey'', OH.C_Company As ''C_Company'' ' + CHAR(13)
      --                            + N' FROM dbo.ORDERS OH WITH (NOLOCK) ' + CHAR(13)
      --                            + N' INNER JOIN dbo.CONTAINER CONT WITH (NOLOCK) ' + CHAR(13)
      --                            + N' ON (CONT.Mbolkey = OH.Mbolkey AND ISNULL(RTRIM(CONT.ExternContainerKey), '''') <> '''' ) ' + CHAR(13)
      --                            + @c_WhereClauseCondi
      --                            + N' ORDER BY '
      --                            + CASE WHEN ISNULL(RTRIM(@c_OrderByOpt), '') <> '' THEN @c_OrderByOpt ELSE ' OH.OrderKey ' + CHAR(13) END
      --                            + N' OFFSET ' + RTRIM(CONVERT(CHAR, ISNULL(@n_CurrRecordNo, 0))) + CHAR(13) 
      --                            + N' ROWS FETCH NEXT ' + RTRIM(CONVERT(CHAR, ISNULL(@n_TtlSelRecord, 10))) + ' ROWS ONLY' 
      --                            + N' FOR XML PATH (''Data''), TYPE) ' --, ROOT(''Response'') '
      --                            + N' FOR XML PATH(''Response'')'
      --                            + N')), '''') '

      --      SET @c_ExecArguments = N'@c_OrderNumber NVARCHAR(10), @c_CustomerName_Condi NVARCHAR(47), @c_ContainerNumber NVARCHAR(30), '
      --                           + N'@c_StorerKey NVARCHAR(15), @n_CountRecord INT, @c_ResponseString NVARCHAR(MAX) OUTPUT'

      --      IF @b_Debug = 1
      --      BEGIN
      --         PRINT '>>>>>> Generate OUTBOUND RESPONSE XML QUERY'
      --         PRINT @c_ExecStatements
      --      END

      --      EXECUTE sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_OrderNumber, @c_CustomerName_Condi, @c_ContainerNumber
      --                          , @c_StorerKey, @n_CountRecord, @c_ResponseString OUTPUT
      --   END
      --END
   END

   QUIT:
   IF @n_Continue= 3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_Success = 0      
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1 
      BEGIN               
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END   
      RETURN      
   END      
   ELSE      
   BEGIN
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END
END -- Procedure  

GO