SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Stored Proceduew Name: isp_PTL_LightUpTowerLight                           */
/* Copyright: IDS                                                             */
/* Purpose: LFLightLink Integration SP                                        */
/*          This SP is to Light Up Tower Light                                */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-03-14 1.0  ChewKP     WMS-3962 Created                                */
/* 2022-03-22 1.1  yeekung    WMS-18729 add params (Yeekung01)                */
/* 2021-09-18 1.2  YeeKung    WMS-17960 Add lightcolour(yeekung01)            */ 
/* 2024-07-30 1.3  yeekung    UWP-22410 Add new Column(yeekung05)					*/
/******************************************************************************/

CREATE   PROC [PTL].[isp_PTL_LightUpTowerLight]
(
   @c_StorerKey NVARCHAR(15)
  ,@n_Func      INT
  ,@c_DeviceID  NVARCHAR(20)
  ,@c_LightAddress  NVARCHAR(MAX)
  ,@c_ActionType    NVARCHAR(10) -- ON, OFF
  ,@c_DeviceIP      NVARCHAR(40)
  ,@b_Success   INT OUTPUT
  ,@n_Err       INT OUTPUT
  ,@c_ErrMsg    NVARCHAR(215) OUTPUT
  ,@c_LModMode  NVARCHAR(10) = ''  --(yeekung01) 
  ,@c_DeviceModel     NVARCHAR(20) = 'Light'
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE --@c_DeviceIP        NVARCHAR(40),
           @nTranCount        INT,
           @c_PutawayZone     NVARCHAR(10),
           --@c_LightAddress  NVARCHAR(20),
           @c_DeviceType      NVARCHAR(20),
           @c_CurrDeviceID    NVARCHAR(20),
           @c_LightAction     NVARCHAR(20),
           @c_LightCommand    NVARCHAR(2000),
           @c_TCPMessage      NVARCHAR(2000),
           @n_PTLKey          BIGINT,
           @c_PTLType         NVARCHAR(10),
           --@c_LightAddress    NVARCHAR(MAX),
           @n_LightLinkLogKey INT,
           @c_CommandValue    NVARCHAR(2000),
			  @cFacility		  NVARCHAR(20)


   DECLARE @nStart INT
          ,@nEnd   INT

   IF @c_DeviceID <> ''
   BEGIN
      --SET @c_DeviceIP = ''
      SELECT TOP 1 --@c_DeviceIP = ISNULL(ll.IPAddress,'')
            @c_DeviceType = ll.DeviceType,
				 @cFacility = ll.Facility
      FROM DeviceProfile ll WITH (NOLOCK)
      WHERE ll.DeviceID = @c_DeviceID

      SET @c_PTLType = @c_DeviceType
   END

   IF ISNULL(RTRIM(@c_DeviceIP), '') = ''
   BEGIN
      SET @n_Err = 85701
      SET @c_ErrMsg = '85701 Bad DeviceID (not found in DeviceProfile)'
      GOTO Quit
   END

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN isp_PTL_LightUpTowerLight -- For rollback or commit only our own transaction



   IF LEN(@c_LightAddress) > 0
   BEGIN

      SET @c_LightAction ='TowerLightT'
      SET @c_LightCommand = [PTL].fnc_PTL_GenLightCommand(@c_LightAction, '', '',@c_DeviceModel)

      --SET @c_ModeArray = RTRIM(@c_ModeArray) + 'm4' +
      --          '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
      --                PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4))

      IF @c_ActionType = 'ON'
      BEGIN
         SET @c_CommandValue = '1'
      END
      ELSE
      IF @c_ActionType = 'OFF'
      BEGIN
         SET @c_CommandValue = '0'
      END

		SET @cFacility = CASE WHEN ISNULL(@cFacility,'') ='' THEN '' ELSE @cFacility END

      SET @c_LightCommand = @c_LightCommand + @c_LightAddress  + @c_CommandValue

      INSERT INTO PTL.LFLightLinkLOG(
            Application, LocalEndPoint,   RemoteEndPoint,
            SourceKey,      MessageType,     Data,
            Status,      AddDate,         DeviceIPAddress, Facility)
      VALUES(
            'LFLigthLink', '' , '',
            '0', 'COMMAND', @c_LightCommand ,
            '0', GetDate(),  @c_DeviceIP,@cFacility )

      SET @n_LightLinkLogKey = @@identity

      UPDATE PTL.LFLightLinkLog WITH (ROWLOCK)
      SET SourceKey = @n_LightLinkLogKey
      WHERE SerialNo = @n_LightLinkLogKey

      --SET @n_LightLinkLogKey = RIGHT((REPLICATE(' ', 7) + CAST(@n_LightLinkLogKey AS VARCHAR(8))), 8)
      SET @c_TCPMessage = @n_LightLinkLogKey

		IF EXISTS (	SELECT 1
						FROM DeviceProfile (NOLOCK)
						WHERE DeviceID = @c_DeviceID
							AND ISNULL(Facility,'') ='')
		BEGIN
    
			--(yeekung01)       
			EXEC PTL.isp_PTL_SendMsg 
				@c_StorerKey = @c_StorerKey, 
				@c_Message  = @c_TCPMessage, 
				@b_success = @b_success OUTPUT, 
				@n_Err     = @n_Err OUTPUT, 
				@c_ErrMsg  = @c_ErrMsg OUTPUT, 
				@c_DeviceType = @c_DeviceType,
				@c_DeviceID = @c_DeviceID,
				@n_Func = @n_Func,
				@cPTSZone = '',
				@cLightcmd = @c_LightCommand
		END

      --SET @c_LightAddress = ''
   END


   -- Updating PTL.LightStatus and PTL Tran
   IF NOT EXISTS (SELECT 1 FROM PTL.LightStatus AS ls WITH (NOLOCK)
                  WHERE ls.IPAddress = @c_DeviceIP
                  AND   ls.DevicePosition = @c_LightAddress
						AND   ls.Facility = @cFacility)
   BEGIN
      INSERT INTO PTL.LightStatus
      (  IPAddress,        DevicePosition,   DeviceID,
         [Status],         PTLKey,           PTLType,
         StorerKey,        UserName,         DisplayValue,
         ReceiveValue,     ReceiveTime,      Remarks,  Func ,
         ErrorMessage,     SourceKey,        DeviceProfileLogKey, LightCmd,Facility )
      VALUES
      (  @c_DeviceIP,      @c_LightAddress, @c_DeviceID,
         '0',              0,                 @c_PTLType,
         @c_StorerKey,     SUSER_SNAME(),     '',
         '',               NULL,              '',  @n_Func ,
         '',               '',        '', @c_LightCommand,@cFacility)
   END
   ELSE
   BEGIN
      UPDATE PTL.LightStatus WITH (ROWLOCK)
         SET [Status] = '0',
             PTLKey   = 0,
             PTLType  = '',
             StorerKey = @c_StorerKey,
             UserName = SUSER_SNAME(),
             DisplayValue = '',
             ReceiveValue = '',
             ReceiveTime = NULL,
             Remarks = '',
             ErrorMessage = '',
             SourceKey = '' ,
             LightCmd = @c_LightCommand,
             Func = @n_Func
      WHERE IPAddress = @c_DeviceIP
      AND   DevicePosition = @c_LightAddress
		AND   Facility = @cFacility
   END


--   IF LEN(@c_LightAddress) > 0
--   BEGIN
--      SET @c_LightAction ='TerminateModule'
--      SET @c_LightCommand = [PTL].fnc_PTL_GenLightCommand(@c_LightAction, '', '')
--
--      INSERT INTO PTL.LFLightLinkLOG(
--             Application, LocalEndPoint,   RemoteEndPoint,
--             SourceKey,      MessageType,     Data,
--             Status,      AddDate,         DeviceIPAddress )
--      VALUES(
--             'LFLigthLink', '' , '',
--             '0', 'COMMAND', @c_LightCommand + @c_LightAddress,
--             '0', GetDate(), @c_DeviceIP  )
--
--      SET @n_LightLinkLogKey = @@identity
--
--      UPDATE PTL.LFLightLinkLog WITH (ROWLOCK)
--      SET SourceKey = @n_LightLinkLogKey
--      WHERE SerialNo = @n_LightLinkLogKey
--
--      --SET @n_LightLinkLogKey = RIGHT((REPLICATE(' ', 7) + CAST(@n_LightLinkLogKey AS VARCHAR(8))), 8)
--      SET @c_TCPMessage = @n_LightLinkLogKey
--
--      EXEC PTL.isp_PTL_SendMsg @c_StorerKey, @c_TCPMessage, @b_success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @c_DeviceType
--                              ,@c_DeviceID
--
--      SET @c_LightAddress = ''
--   END

   COMMIT TRAN isp_PTL_LightUpTowerLight
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN isp_PTL_LightUpTowerLight -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END



GO