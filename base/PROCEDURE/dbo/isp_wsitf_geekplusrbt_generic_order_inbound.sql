SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/              
/* Store procedure: isp_WSITF_GEEKPLUSRBT_GENERIC_ORDER_INBOUND         */              
/* Creation Date: 21-JUN-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: KCY                                                      */
/*                                                                      */
/* Purpose: Pass Incoming Request String For Interface                  */
/*                                                                      */
/* Input Parameters:  @b_Debug            - 0                           */
/*                    @c_Format           - 'JSON'                      */
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
/* 2018-06-21  KCY      Initial - Jira Ticket #WMS-5291                 */
/* 2020-07-17  Alex     AGV change revervation to reservation           */
/************************************************************************/    
CREATE PROC [dbo].[isp_WSITF_GEEKPLUSRBT_GENERIC_ORDER_INBOUND](
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

         , @c_Application                 NVARCHAR(50)
         , @c_MessageType                 NVARCHAR(10)

         , @c_Facility                    NVARCHAR(5)
         , @c_StorerKey                   NVARCHAR(15)

         , @c_pallet_code                 NVARCHAR(18)
         , @c_transaction_id              NVARCHAR(32)
         , @c_sku_code                    NVARCHAR(20)
         , @c_status                      NVARCHAR(5)
         , @c_owner_code                  NVARCHAR(16)
         , @n_sku_receive_amount          INT

         , @c_Lot                         NVARCHAR(10)
         , @c_FromLoc                     NVARCHAR(10)
         , @c_FromLocPickZone             NVARCHAR(10)
         , @c_ToRobotLoc                  NVARCHAR(10)
         , @c_ToRobotHOLDLoc              NVARCHAR(10)
         , @n_CurrentLLIQTY               INT
         , @c_ListName_ROBOTSTR           NVARCHAR(10)
         , @n_Exists                      INT
         , @n_QtyNotReceived              INT
         , @n_QtyReceived                 INT

   DECLARE @c_OrderType                   NVARCHAR(32)
         , @c_RequestKey                  NVARCHAR(32)
         , @c_DropId                      NVARCHAR(32)
         , @c_SKU                         NVARCHAR(32)
         , @n_Amount                      INT
         , @n_PickDetAmount               INT
         , @c_Orderkey                    NVARCHAR(20)
         , @c_PickDetailKey               NVARCHAR(10)
         , @n_RequestAmount               INT
         , @c_ShortPick                   NVARCHAR(20)
         , @c_FULLPick                    NVARCHAR(20)
         , @c_PickLoc                     NVARCHAR(10)
         , @n_OrderAmount                 INT
         , @n_ChckLastRqt                 INT
         , @cNewPickDetailKey             NVARCHAR( 10)

   SET @n_Continue                        = 1
   SET @n_StartCnt                        = @@TRANCOUNT
   SET @b_Success                         = 1
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   
   SET @c_Application                     = 'GEEK+_ORDER_RESPONSE_IN'
   SET @c_MessageType                     = 'WS_IN'

   SET @c_Facility                        = ''
   SET @c_StorerKey                       = ''

   SET @c_pallet_code                     = ''
   SET @c_sku_code                        = ''
   SET @c_owner_code                      = ''
   SET @n_sku_receive_amount              = 0

   SET @c_Lot                             = ''
   SET @c_FromLoc                         = ''
   SET @c_ToRobotLoc                      = ''
   SET @c_ToRobotHOLDLoc                  = ''
   SET @n_CurrentLLIQTY                   = 0
   SET @c_ListName_ROBOTSTR               = 'ROBOTSTR'
   SET @n_QtyNotReceived                  = 0 
   SET @n_QtyReceived                     = 0 

   SET @c_OrderType                       = ''
   SET @c_RequestKey                      = ''
   SET @c_DropId                          = ''
   SET @c_SKU                             = ''
   SET @n_Amount                          = 0
   SET @n_RequestAmount                     = 0
   SET @c_Orderkey                        = ''
   SET @c_PickDetailKey                   = ''
   SET @c_ShortPick                       = '4'
   SET @c_FULLPick                        = '3'
   SET @c_PickLoc                         = ''
   SET @n_OrderAmount                     = 0
   SET @n_ChckLastRqt                     = 0

   BEGIN TRAN

   IF OBJECT_ID('tempdb..#TEMP_GEEK_ORDERTYPE') IS NOT NULL
   DROP TABLE #TEMP_GEEK_ORDERTYPE

   CREATE TABLE #TEMP_GEEK_ORDERTYPE(
      OrderType   NVARCHAR(50)  NULL,
      owner_code  NVARCHAR(32)  NULL
   )

   IF NOT ISJSON(@c_RequestString) > 0
   BEGIN
      SET @n_Continue = 3
      SET @n_ErrNo = 210000
      SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - invalid JSON request..'
      GOTO QUIT
   END

   INSERT INTO #TEMP_GEEK_ORDERTYPE (OrderType, owner_code)
   SELECT order_list.reservation1, order_list.owner_code --order_list.revervation1
   FROM OPENJSON(@c_RequestString, '$.body.order_list')
   WITH (
      reservation1         NVARCHAR(50)      '$.reservation1',
      --revervation1         NVARCHAR(50)      '$.revervation1'
      owner_code           NVARCHAR(50)      '$.owner_code'
   ) As order_list
   GROUP BY order_list.reservation1, order_list.owner_code

   SET @n_Exists = 0
   SELECT @n_Exists = (1), @c_OrderType = ISNULL(RTRIM(OrderType), '')
   FROM #TEMP_GEEK_ORDERTYPE 
   WHERE OrderType NOT IN ('LOAD', 'BATCH', 'ORDER', 'WAVESKU')

   IF @n_Exists = 1
   BEGIN
      SET @n_ErrNo = 230400                                                                       
      SET @c_ErrMsg = 'Invalid OrderType - ' + @c_OrderType
      GOTO QUIT
   END

   SET @n_Exists = 0
   SELECT @n_Exists = (1)
         ,@c_owner_code = owner_code
   FROM #TEMP_GEEK_ORDERTYPE temp
   WHERE NOT EXISTS ( SELECT 1 
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE ListName = 'ROBOTSTR'
      AND [Short] = temp.owner_code
   )

   IF @n_Exists = 1
   BEGIN
      SET @n_ErrNo = 230400                                                                       
      SET @c_ErrMsg = 'Invalid owner_code - ' + @c_owner_code
      GOTO QUIT
   END

   DECLARE GEEKPLUS_ORDTYPE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderType, owner_code 
   FROM #TEMP_GEEK_ORDERTYPE

   OPEN GEEKPLUS_ORDTYPE  

   FETCH NEXT FROM GEEKPLUS_ORDTYPE INTO @c_OrderType, @c_owner_code
   WHILE @@FETCH_STATUS = 0 
   BEGIN
      SELECT @c_StorerKey = StorerKey
      FROM dbo.Codelkup WITH (NOLOCK) 
      WHERE ListName = 'ROBOTSTR'
      AND [Short] = @c_owner_code
      
      EXEC dbo.isp_WSITF_GEEKPLUSRBT_GENERIC_ORDER_INBOUND_POST
           @b_Debug 
         , @c_OrderType
         , @c_owner_code
         , @c_StorerKey
         , @c_RequestString 
         , @b_Success        OUTPUT
         , @n_ErrNo          OUTPUT
         , @c_ErrMsg         OUTPUT
         , @c_ResponseString OUTPUT
         IF @b_Success <> 1
         BEGIN
            SET @n_Continue = 3
            SET @n_ErrNo = 230401  
            SET @c_ErrMsg = 'FAILED TO Execute isp_WSITF_GEEKPLUSRBT_GENERIC_ORDER_INBOUND_POST! Msg=' + @c_ErrMsg
            GOTO QUIT
         END

      FETCH NEXT FROM GEEKPLUS_ORDTYPE INTO @c_OrderType, @c_owner_code
   END
   CLOSE GEEKPLUS_ORDTYPE  
   DEALLOCATE GEEKPLUS_ORDTYPE  

   QUIT:
   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_ORDTYPE') in (0 , 1)  
   BEGIN  
      CLOSE GEEKPLUS_ORDTYPE  
      DEALLOCATE GEEKPLUS_ORDTYPE  
   END

   IF @n_Continue = 3 AND @n_ErrNo <> 0
   BEGIN
      --SET @b_Success = 0      
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
   END      
   ELSE      
   BEGIN      
      --SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END          
   END

   SET @c_ResponseString = ISNULL(RTRIM(
      (
         SELECT 
            CASE WHEN @n_ErrNo > 0 THEN '400' ELSE '200' END As 'header.msgCode'
          , CASE WHEN @n_ErrNo > 0 THEN 'Error : ' + @c_ErrMsg 
               ELSE N'Process with Success' END As 'header.message'
          , CONVERT(BIT, CASE WHEN @n_ErrNo > 0 THEN 0 ELSE 1 END) As 'body.success'
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
      )
   ), '')

   --Insert log to TCPSocket_INLog
   INSERT INTO dbo.TCPSOCKET_INLOG ( [Application], MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )
   VALUES ( @c_Application, @c_MessageType, @c_MessageType, @c_RequestString, '', @c_StorerKey, @c_ResponseString, '9' )

   --Build Custom Response
   SELECT @n_ErrNo = 0, @b_Success = 1, @c_ErrMsg = ''
   RETURN
END -- Procedure  

GO