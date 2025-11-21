SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: isp_FedEx_DeleteShipment                                         */
/* Creation Date: 01 Nov 2011                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose: Send Delete Shipment Web Service Request to FedEx           */
/*          (SOS#226384)                                                */ 
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
/* 27Jan2012    NJOW01   1.0      Delete CartonShipmentDetail           */
/* 09-Feb-2012  Chee     1.1      Add debug and FilePath parameter in   */
/*                                isp_FedEx_DeleteShipment (Chee01)     */
/************************************************************************/

CREATE PROC [dbo].[isp_FedEx_DeleteShipment]
     @c_UserCrendentialKey       NVARCHAR(30)
   , @c_UserCredentialPassword   NVARCHAR(30)
   , @c_ClientAccountNumber      NVARCHAR(18)
   , @c_ClientMeterNumber        NVARCHAR(18)
   , @c_TrackingNumber           NVARCHAR(15)
   , @c_UspsApplicationId        NVARCHAR(30)
   , @c_ServiceType              NVARCHAR(30)
   , @b_Success                  INT            OUTPUT
   , @n_err                      INT            OUTPUT
   , @c_errmsg                   NVARCHAR(250)   OUTPUT
   --, @x_Message                XML            OUTPUT            
AS
BEGIN

   SET ANSI_PADDING ON
   SET ANSI_WARNINGS ON
   SET CONCAT_NULL_YIELDS_NULL ON
   SET ARITHABORT ON

   DECLARE 
      @n_TrackingIdType                INT
    --,@c_result                       NVARCHAR(MAX)    -- Chee01
      ,@c_vbErrMsg                     NVARCHAR(MAX)
      ,@c_NotificationHighestSeverity  NVARCHAR(10)
      ,@x_Message                      XML
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

   -- ************************************* --
   --          TrackingIdType        --
   -- ************************************* --
   /*
   FIRST_OVERNIGHT                  -  FEDEX
   PRIORITY_OVERNIGHT               -  FEDEX
   STANDARD_OVERNIGHT               -  FEDEX
   FEDEX_2_DAY                      -  FEDEX
   FEDEX_EXPRESS_SAVER              -  FEDEX
   FEDEX_1_DAY_FREIGHT              -  FREIGHT
   FEDEX_2_DAY_FREIGHT              -  FREIGHT
   FEDEX_3_DAY_FREIGHT              -  FREIGHT
   FEDEX_GROUND                     -  GROUND
   GROUND_HOME_DELIVERY             -  GROUND
   INTERNATIONAL_PRIORITY           -  TBD ?Phase2
   INTERNATIONAL_ECONOMY            -  TBD ?Phase2
   INTERNATIONAL_FIRST              -  TBD ?Phase2
   INTERNATIONAL_PRIORITY_FREIGHT   -  TBD ?Phase2
   INTERNATIONAL_ECONOMY_FREIGHT    -  TBD ?Phase2
   SMART_POST                       -  TBD ?Phase2
   */
   -- EXPRESS = 0, FEDEX = 1, FREIGHT = 2, GROUND = 3, USPS = 4
   
   IF ISNULL(@c_ServiceType,'') = ''
   BEGIN
      SET @b_Success = 0
      SET @n_err = 80000
      SET @c_errmsg = 'ServiceType is null.'
      GOTO QUIT
   END
   -- EXPRESS
   ELSE IF @c_ServiceType = 'EXPRESS'  -- TBD
   BEGIN
      SET   @n_TrackingIdType = 0      
   END
   -- FEDEX
   ELSE IF @c_ServiceType = 'FIRST_OVERNIGHT' OR @c_ServiceType = 'PRIORITY_OVERNIGHT' OR @c_ServiceType = 'STANDARD_OVERNIGHT' 
         OR @c_ServiceType = 'FEDEX_2_DAY'   OR @c_ServiceType = 'FEDEX_EXPRESS_SAVER'
   BEGIN
      SET   @n_TrackingIdType = 1
   END
   -- FREIGHT
   ELSE IF @c_ServiceType = 'FEDEX_1_DAY_FREIGHT' OR @c_ServiceType = 'FEDEX_2_DAY_FREIGHT' OR @c_ServiceType = 'FEDEX_3_DAY_FREIGHT' 
   BEGIN
      SET   @n_TrackingIdType = 2      
   END
   -- GROUND
   ELSE IF @c_ServiceType = 'FEDEX_GROUND' OR @c_ServiceType = 'GROUND_HOME_DELIVERY'
   BEGIN
      SET   @n_TrackingIdType = 3      
   END
   -- USPS
   ELSE IF @c_ServiceType = 'USPS' -- TBD
   BEGIN
      SET   @n_TrackingIdType = 4      
   END
   ELSE
   BEGIN
      SET @b_Success = 0
      SET @n_err = 80001
      SET @c_errmsg = 'Invalid ServiceType.'
      GOTO QUIT
   END

   EXEC [master].[dbo].[isp_DeleteShipment]
        @c_IniFileDirectory         -- Chee01
      ,@n_debug                     -- Chee01
      ,@c_UserCrendentialKey             
      ,@c_UserCredentialPassword        
      ,@c_ClientAccountNumber           
      ,@c_ClientMeterNumber             
      ,@c_TrackingNumber         
      ,@c_UspsApplicationId
      ,@n_TrackingIdType              
    --,@c_result    OUTPUT          -- Chee01
      ,@c_Request   OUTPUT          -- Chee01
      ,@c_Reply     OUTPUT          -- Chee01
      ,@c_vbErrMsg   OUTPUT

   IF @@ERROR <> 0 OR ISNULL(@c_vbErrMsg,'') <> '' 
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
         SET @n_err = 80002
      END

      -- SET @c_errmsg
      IF ISNULL(@c_vbErrMsg,'') <> ''   
      BEGIN
         SET @c_errmsg = CAST(@c_vbErrMsg AS NVARCHAR(250))
      END
      ELSE
      BEGIN
         SET @c_errmsg = 'Error: '+ CAST(@n_err AS NVARCHAR(11)) + ' occurred while executing [master].[dbo].[isp_DeleteShipment].' 
      END   

      GOTO QUIT
   END

   -- Chee01
   --SET @x_Message = CAST(@c_result AS XML)    
   SET @x_Message = CAST(@c_Reply AS XML)  

   -- HIGHEST SEVERITY
   ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)
   SELECT @c_NotificationHighestSeverity = nref.value('ns:HighestSeverity[1]', 'VARCHAR(10)')
   FROM @X_Message.nodes('/ShipmentReply') AS R(nref)

   IF @c_NotificationHighestSeverity = 'ERROR' OR @c_NotificationHighestSeverity = 'FAILURE' OR @c_NotificationHighestSeverity = 'NOTE'
   BEGIN
      -- SET @b_Success, @n_err & @c_errmsg
      SET @b_Success = 0
      SET @n_err = 80003
      SET @c_errmsg = ''

      ;WITH XMLNAMESPACES ('http://fedex.com/ws/ship/v10' As ns)
      SELECT @c_errmsg = 
      @c_errmsg + 'Severity: ' + nref.value('ns:Severity[1]', 'VARCHAR(10)') +
      ', ErrMsg: ' + nref.value('ns:Message[1]', 'VARCHAR(100)') + '; '
      FROM @x_Message.nodes('/ShipmentReply/ns:Notifications') AS R(nref)
      WHERE nref.value('ns:Severity[1]', 'VARCHAR(10)') = 'ERROR' 
      OR nref.value('ns:Severity[1]', 'VARCHAR(10)') = 'FAILURE'
      OR nref.value('ns:Severity[1]', 'VARCHAR(10)') = 'NOTE'

      GOTO QUIT
   END
   ELSE
   BEGIN

      BEGIN TRAN

      -- UPDATE FedExTracking status to CANC
      UPDATE FedExTracking WITH (ROWLOCK)
      SET Status = 'CANC', SendFlag = 'Y', UpdateSource = 'isp_FedEx_DeleteShipment'
      WHERE Status = '0' AND TrackingNumber = @c_TrackingNumber AND ServiceType = @c_ServiceType

      -- REMOVE Tracking Number
      UPDATE PACKDETAIL WITH (ROWLOCK)
      SET UPC = NULL
      WHERE UPC = @c_TrackingNumber 

      --NJOW01 
    
	    DELETE FROM CartonShipmentDetail WITH (ROWLOCK)
	    WHERE TrackingNumber = @c_TrackingNumber
       --NJOW01
      IF @@TRANCOUNT > 0
      BEGIN 
         COMMIT TRAN;
      END
      ELSE
      BEGIN 
         ROLLBACK TRAN
      END
   END

QUIT:
   RETURN;
END


GO