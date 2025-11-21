SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: isp_FedEx_CloseShipment_SmartPost                                */
/* Creation Date: 01 Nov 2011                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Send SmartPost Close Shipment Web Service Request to FedEx  */
/*          (SOS#227408)                                                */ 
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver      Purposes                              */
/* 09-Feb-2012  Chee     1.1      Add debug and FilePath parameter in   */
/*                                isp_CloseShipment_SmartPost (Chee01)  */
/************************************************************************/

CREATE PROC [dbo].[isp_FedEx_CloseShipment_SmartPost]
(
     @c_UserCrendentialKey       NVARCHAR(30)    -- NVARCHAR(MAX)
   , @c_UserCredentialPassword   NVARCHAR(30)    -- NVARCHAR(MAX)
   , @c_ClientAccountNumber      NVARCHAR(18)    -- NVARCHAR(MAX)
   , @c_ClientMeterNumber        NVARCHAR(18)    -- NVARCHAR(MAX)
   , @b_Success                  INT            OUTPUT
   , @n_err                      INT            OUTPUT
   , @c_errmsg                   NVARCHAR(250)   OUTPUT
-- , @c_Type                     NVARCHAR(15)    OUTPUT
-- , @c_ShippingCycle            NVARCHAR(20)    OUTPUT
-- , @c_Label                    NVARCHAR(MAX)   OUTPUT
)
AS
BEGIN

   DECLARE 
      --@c_result                       NVARCHAR(MAX)    -- Chee01
       @x_Message                      XML
      ,@c_vbErrMsg                     NVARCHAR(MAX)  
      ,@c_NotificationHighestSeverity  NVARCHAR(10)
      ,@n_debug                        INT               -- Chee01
      ,@c_IniFileDirectory             NVARCHAR(100)     -- Chee01
      ,@c_Request                      NVARCHAR(MAX)     -- Chee01    
      ,@c_Reply                        NVARCHAR(MAX)     -- Chee01

   SET @n_debug = 0     -- Chee01
   SET @b_Success = 1

   -- Chee01
   SELECT @c_IniFileDirectory = LONG
   FROM CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'FEDEX'
     AND Code = 'FilePath'

   EXEC [master].[dbo].[isp_CloseShipment_SmartPost]
        @c_IniFileDirectory         -- Chee01
      , @n_debug                    -- Chee01
      , @c_UserCrendentialKey
      , @c_UserCredentialPassword 
      , @c_ClientAccountNumber 
      , @c_ClientMeterNumber
    --, @c_result    OUTPUT         -- Chee01
      , @c_Request   OUTPUT         -- Chee01
      , @c_Reply     OUTPUT         -- Chee01
      , @c_vbErrMsg  OUTPUT

   IF @@ERROR <> 0 OR @c_vbErrMsg IS NOT NULL
   BEGIN
      -- SET @b_Success
      SET @b_Success = 0

      -- SET @n_err
      IF @@ERROR <> 0
      BEGIN
         SET @n_err = @@ERROR
      END
      ELSE
      BEGIN
         SET @n_err = 90000
      END

      -- SET @c_errmsg
      IF @c_vbErrMsg IS NOT NULL
      BEGIN
         SET @c_errmsg = CAST(@c_vbErrMsg AS NVARCHAR(250))
      END
      ELSE
      BEGIN
         SET @c_errmsg = 'Error: '+ CAST(@n_err AS NVARCHAR(11)) + ' occurred while executing [master].[dbo].[isp_CloseShipment_SmartPost].' 
      END   

      GOTO QUIT
   END

   -- Chee01
   --SET @x_Message = CAST(@c_result AS XML)    
   SET @x_Message = CAST(@c_Reply AS XML)    

   -- HIGHEST SEVERITY
   ;WITH XMLNAMESPACES ('http://fedex.com/ws/close/v2' As ns)
   SELECT @c_NotificationHighestSeverity = nref.value('ns:HighestSeverity[1]', 'VARCHAR(10)')
   FROM @X_Message.nodes('/SmartPostCloseReply') AS R(nref)

   IF @c_NotificationHighestSeverity = 'ERROR' OR @c_NotificationHighestSeverity = 'FAILURE' 
   BEGIN
      -- SET @b_Success, @n_err & @c_errmsg
      SET @b_Success = 0
      SET @n_err = 90001
      SET @c_errmsg = ''

      ;WITH XMLNAMESPACES ('http://fedex.com/ws/close/v2' As ns)
      SELECT @c_errmsg = 
      @c_errmsg + 'Severity: ' + nref.value('ns:Severity[1]', 'VARCHAR(10)') +
      ', ErrMsg: ' + nref.value('ns:Message[1]', 'VARCHAR(100)') + '; '
      FROM @x_Message.nodes('/SmartPostCloseReply/ns:Notifications') AS R(nref)
      WHERE nref.value('ns:Severity[1]', 'VARCHAR(10)') = 'ERROR' 
      OR nref.value('ns:Severity[1]', 'VARCHAR(10)') ='FAILURE'

      GOTO QUIT
   END
-- ELSE
-- BEGIN
--    ;WITH XMLNAMESPACES ('http://fedex.com/ws/close/v2' As ns)
--    SELECT @c_Type = nref.value('ns:../Type[1]', 'VARCHAR(15)'),
--          @c_ShippingCycle = nref.value('ns:../ShippingCycle[1]', 'VARCHAR(20)'),
--          @c_Label = nref.value('ns:Image[1]', 'VARCHAR(MAX)')
--    FROM @x_Message.nodes('/SmartPostCloseReply/ns:CloseDocuments/ns:Parts') AS R(nref)
-- END

QUIT:
   RETURN;

END   


GO