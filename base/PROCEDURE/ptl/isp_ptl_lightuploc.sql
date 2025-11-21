SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

    
/******************************************************************************/    
/* Stored Procedure:  isp_PTL_LightUpLoc                                      */    
/* Copyright: IDS                                                             */    
/* Purpose: BondDPC Integration SP                                            */    
/*                                                                            */    
/* Modifications log:                                                         */    
/*                                                                            */    
/* Date       Rev  Author     Purposes                                        */    
/* 2013-02-15 1.0  Shong      Created                                         */    
/* 2015-06-25 1.2  ChewKP     Change to PTL.Schema (ChewKP02)                 */    
/* 2016-03-22 1.3  Ung        Update PTLTran.LightUp                          */    
/* 2017-08-16 1.4  ChewKP     Performance Fix (ChewKP03)                      */  
/* 2019-07-06 1.5  YeeKung    Add Zone feature     (yeekung01)                */   
/* 2020-11-01 1.6  YeeKung    WMS-14911 Add Fn Close(yeekung02)               */   
/* 2020-11-01 1.6  YeeKung    WMS-16066 Add loc pickzone(yeekung02)           */   
/* 2022-03-22 1.7  yeekung    WMS-18729 add params (Yeekung04)                */
/* 2023-04-06 1.8  yeekung    WMS-22163 Merge all lightup                     */ 
/* 2024-07-30 1.9  yeekung    UWP-22410 Add new Column(yeekung05)					*/
/******************************************************************************/    
CREATE   PROC [PTL].[isp_PTL_LightUpLoc]    
(    
   @n_Func           INT    
  ,@n_PTLKey         BIGINT    
  ,@c_DisplayValue   NVARCHAR(10)    
  ,@b_Success        INT OUTPUT    
  ,@n_Err            INT OUTPUT    
  ,@c_ErrMsg         NVARCHAR(215) OUTPUT    
  ,@c_ForceColor     NVARCHAR(20) = ''    
  ,@c_DeviceID       NVARCHAR(20) = ''    
  ,@c_DevicePos      NVARCHAR(MAX) = ''    
  ,@c_DeviceIP       NVARCHAR(40) = ''    
  ,@c_LModMode       NVARCHAR(10) = ''    
  ,@c_DeviceProLogKey NVARCHAR(10) = ''   
  ,@c_DeviceModel     NVARCHAR(20) = 'Light'
  ,@c_ActionType     NVARCHAR(10) = ''
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE --@c_DeviceIP        VARCHAR(40),    
           @c_LightCommand    VARCHAR(MAX),    
           @c_TCPMessage      VARCHAR(2000),    
           @n_IsRDT           INT,    
           @n_StartTCnt       INT,    
           @n_Continue        INT,    
           @c_DeviceType      NVARCHAR(20),    
           --@c_DeviceProLogKey NVARCHAR(10),    
           @c_LightAction     NVARCHAR(20),    
           @c_PTLKey          CHAR(10),    
           @n_LenOfValues     INT,      
           @c_CommandValue    NVARCHAR(15),     
           @nTranCount        INT,    
           @cPTSZone          NVARCHAR(10)    
        
   DECLARE @c_StorerKey      NVARCHAR(15)                
          --,@c_DeviceID       VARCHAR(20)                
          --,@c_DevicePos      VARCHAR(10)       
          --,@c_LModMode       NVARCHAR(10)    
          ,@n_LightLinkLogKey INT    
          ,@dAddDate         DATETIME    
          ,@cLoc             NVARCHAR(20)
          ,@cLightcmd       NVARCHAR(MAX)
			 ,@cFacility		  NVARCHAR(20)
    
   SET @n_StartTCnt = @@TRANCOUNT    
   SET @n_Continue = 1    
    
--   IF NOT EXISTS(SELECT 1 FROM PTL.PTLTran p WITH (NOLOCK)    
--                 WHERE p.PTLKey = @n_PTLKey    
--                   AND p.[Status]<>'9')    
--   BEGIN    
--      SET @n_Err = 94052    
--      SET @c_ErrMsg = '94052 - No Record Found in PTLTRAN, PTLKey=' + CAST(@n_PTLKey AS VARCHAR(10))    
--      SET @n_Continue=3    
--      GOTO EXIT_SP    
--   END    


	SELECT   @cFacility = Facility
	FROM DeviceProfile ll WITH (NOLOCK)    
	WHERE ll.DeviceID = @c_DeviceID   
		AND ll.DevicePosition=@c_DevicePos 
		AND ll.IPAddress=@c_DeviceIP

   IF  @c_DeviceModel NOT IN ('TMS')
   BEGIN
      IF (@c_DeviceID = '' AND  @c_DevicePos = '' AND  @c_DeviceIP = '' )       
      BEGIN    
         IF ISNULL(@n_PTLKey,0) = 0    
         BEGIN    
            SET @n_Err = 94051    
            SET @c_ErrMsg = '94051 - PTLKey Requied'    
            SET @n_Continue=3    
            GOTO Quit    
         END    
    
    
         --SET @c_DeviceIP = ''    
         SELECT @c_StorerKey = p.Storerkey,    
                @c_DeviceID  = p.DeviceID,    
                @c_DeviceIP  = p.IPAddress,    
                @c_DevicePos = p.DevicePosition,    
                @c_LModMode  = p.LightMode    
                --@c_DisplayValue = p.DisplayValue    
         FROM   PTL.PTLTran AS p WITH (NOLOCK)    
         WHERE p.PTLKey = @n_PTLKey    
         AND   p.[Status]<>'9'    
    
    
      END    
      ELSE --IF @c_DeviceID <> ''    
      BEGIN    
         SELECT   @c_DeviceType = ll.DeviceType    
                 --,@c_DeviceProLogKey = ll.DeviceProfileLogKey    
                 ,@c_StorerKey = ll.StorerKey  
                 , @cLoc=  ll.Loc
         FROM DeviceProfile ll WITH (NOLOCK)    
         WHERE ll.DeviceID = @c_DeviceID   
         AND ll.DevicePosition=@c_DevicePos 
         AND ll.IPAddress=@c_DeviceIP
      END    
    
      IF ISNULL(RTRIM(@c_LModMode),'')  = ''    
      BEGIN    
         SET @c_LModMode = rdt.RDTGetConfig( @n_Func, 'LightMode', @c_StorerKey)    
      END    
    
      IF ISNULL(RTRIM(@c_DeviceIP), '') = '' AND  @c_DeviceModel NOT IN ('TMS')      
      BEGIN    
         SET @n_Err = 94053    
         SET @c_ErrMsg = '94053 - IP Address cannot be NULL'    
         SET @n_Continue=3    
         GOTO Quit    
      END    
    
      IF ISNULL(RTRIM(@c_DevicePos),'') = ''    
      BEGIN    
         SET @n_Err = 94054    
         SET @c_ErrMsg = '94054 - DevicePosition cannot be NULL'    
         SET @n_Continue = 3    
         GOTO Quit    
      END    
    
      IF ISNULL(RTRIM(@c_LModMode),'') = ''    
      BEGIN    
         SET @n_Err = 94055    
         SET @c_ErrMsg = '94055 - LightMode cannot be NULL'    
         SET @n_Continue =3    
         GOTO Quit    
      END    
    
      IF NOT EXISTS(SELECT 1 FROM DeviceProfile As dp WITH (NOLOCK)    
                    WHERE dp.IPAddress = @c_DeviceIP    
                    AND   dp.DevicePosition = @c_DevicePos)    
      BEGIN    
         SET @n_Err = 94056    
         SET @c_ErrMsg = '94055 - Device Position and Location cannot be found in DeviceProfile'    
         SET @n_Continue = 3    
         GOTO Quit    
      END   
   END

   IF @c_DeviceModel ='TOWER'
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

      SET @c_LightCommand = @c_LightCommand + @c_DevicePos  + @c_CommandValue

   END
   ELSE IF @c_DeviceModel IN ('BATCH','LIGHT')
   BEGIN
      SET @c_LightAction  = 'Operation'    
      SELECT @c_LightCommand = [PTL].fnc_PTL_GenLightCommand(@c_LightAction, @c_LModMode, ISNULL(@c_ForceColor,''),@c_DeviceModel ) --Yeekung04   
      SET @n_LenOfValues = LEN(@c_DisplayValue)  

      --(yeekung01)    
      SELECT @cPTSZone=Putawayzone    
      FROM LOC WITH (NOLOCK)    
      WHERE LOC=@c_DeviceID    

      IF ISNULL(@cPTSZone,'')=''
      BEGIN
         SELECT @cPTSZone=Putawayzone    
         FROM LOC WITH (NOLOCK)    
         WHERE LOC=@cLoc  
      END
   
      IF @c_DeviceModel='BATCH'
      BEGIN
         SET @c_CommandValue = @c_DisplayValue 
      END
      ELSE
      BEGIN
         IF LEN(RTRIM(@c_DisplayValue)) >= 5    
         BEGIN    
      --      SELECT @c_CommandValue = SUBSTRING(p.DisplayValue,1,5)    
      --      FROM   PTL.PTLTran AS p WITH (NOLOCK)    
      --      WHERE p.PTLKey = @n_PTLKey    
      --      AND   p.[Status]='0'    

            SET @c_CommandValue = @c_DisplayValue   
         END    
         ELSE IF @n_LenOfValues < 5    
         BEGIN    
            SELECT @c_CommandValue = CASE @n_LenOfValues    
                                       WHEN '0'  THEN '$20$20$20$20$20'    
                                       WHEN '1'  THEN '$20$20$20$20' + @c_DisplayValue    
                                       WHEN '2'  THEN '$20$20$20' + @c_DisplayValue    
                                       WHEN '3'  THEN '$20$20' + @c_DisplayValue    
                                       WHEN '4'  THEN '$20' + @c_DisplayValue    
            END    
         END 
      END

     
      DECLARE @cFnButton NVARCHAR(10),  
              @cFnCommadValue NVARCHAR(100)  
  
  
      SET @cFnButton=rdt.RDTGetConfig( @n_Func, 'FnButtonClose', @c_StorerKey)    
  
      IF @cFnButton='1'  
      BEGIN  
          SET @cFnCommadValue= 'PP5050501m1$31$22$FFm2$31$22$FFm3$31$FF$3Fma$42'  
          SET @c_LightCommand=@cFnCommadValue+@c_DevicePos+@c_CommandValue++'$20$20CLO'  
      END  
      ELSE IF @c_DeviceModel='BATCH' 
      BEGIN
 
         SET @c_LightCommand = replace(@c_LightCommand,'@cPos',@c_DevicePos)


         SET @c_LightCommand = @c_LightCommand + 
                                CASE WHEN len(@c_CommandValue)<10 THEN '0'+ CAST(len(@c_CommandValue) AS nvarchar(20))
                                ELSE CAST(len(@c_CommandValue) AS nvarchar(20)) END
                               + @c_CommandValue

      END
      ELSE
      BEGIN  
    
         SET @c_LightCommand = @c_LightCommand + @c_DevicePos + @c_CommandValue --+ @c_DisplayValue    
      END  
   END
   ELSE IF @c_DeviceModel IN ('TMS')
   BEGIN
      SELECT top 1 @c_StorerKey=storerkey
      from deviceprofile (nolock)
      where deviceid=@c_DeviceID
      and storerkey<>''

      IF @c_LModMode='0'
      BEGIN
         SELECT @c_LightCommand = [PTL].PTL_GenLightCommand_TMS(@c_DeviceID,@c_DevicePos,@c_LModMode)
      END
      ELSE
      BEGIN
         SELECT @c_LightCommand = [PTL].PTL_GenLightCommand_TMS(@c_DeviceID,@c_DevicePos,@c_LModMode)

      END
      SET @cLightcmd = @c_LightCommand
   END
  
  	SET @cFacility = CASE WHEN ISNULL(@cFacility,'') ='' THEN '' ELSE @cFacility END

   SET @dAddDate = Getdate()    
    
   INSERT INTO PTL.LFLightLinkLOG(    
          Application, LocalEndPoint,   RemoteEndPoint,    
          SourceKey,      MessageType,     Data,    
          Status,      AddDate,         DeviceIPAddress,Facility )    
   VALUES(    
          'LFLigthLink', @c_DeviceIP +':'+'5003' , '',    
          @n_PTLKey, 'COMMAND', @c_LightCommand,    
          '0', @dAddDate, @c_DeviceIP,@cFacility  )    

    
   SET @n_LightLinkLogKey = @@identity    
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
			@cPTSZone = @cPTSZone,
			@cLightcmd = @cLightcmd
	END
    
   IF @n_Err <> 0    
   BEGIN    
      SET @n_Continue=3    
      GOTO Quit    
   END    
   ELSE IF @c_DeviceModel NOT IN ('TMS')
   BEGIN    
      -- Handling transaction    
      SET @nTranCount = @@TRANCOUNT    
      BEGIN TRAN  -- Begin our own transaction    
      SAVE TRAN isp_PTL_LightUpLoc -- For rollback or commit only our own transaction       
    
      INSERT INTO PTL.LightInput ( IPAddress, DevicePosition, OutputData, Status, AddDate,Facility )    
      VALUES ( @c_DeviceIP, @c_DevicePos, @c_DisplayValue, '9' , @dAddDate,@cFacility )    
    
    
      IF NOT EXISTS (SELECT 1 FROM PTL.LightStatus AS ls WITH (NOLOCK)    
                  WHERE ls.IPAddress = @c_DeviceIP    
                  AND   ls.DevicePosition = @c_DevicePos
						AND	ls.Facility = @cFacility)    
      BEGIN    
         INSERT INTO PTL.LightStatus          
         (  IPAddress,        DevicePosition,   DeviceID,          
            [Status],       PTLKey,           PTLType,          
            StorerKey,        UserName,         DisplayValue,          
            ReceiveValue,     ReceiveTime,      Remarks, Func,          
            ErrorMessage,     SourceKey,        DeviceProfileLogKey, LightCmd, EditWho, EditDate,Facility )          
         VALUES          
         (  @c_DeviceIP,      @c_DevicePos,     @c_DeviceID,          
            '0',              @n_PTLKey,        '',          
            @c_StorerKey,     SUSER_SNAME(),    @c_DisplayValue,          
            '',               NULL,             '',    @n_Func,          
    '',               '',               @c_DeviceProLogKey, @c_LightCommand, SUSER_SNAME(), GetDate(),@cFacility )    
      END    
      ELSE    
      BEGIN    
         UPDATE PTL.LightStatus WITH (ROWLOCK)     
            SET [Status] = '0',    
                PTLKey   = @n_PTLKey,    
                PTLType  = '',    
                StorerKey = @c_StorerKey,    
                UserName = SUSER_SNAME(),    
                DisplayValue = @c_DisplayValue,    
                ReceiveValue = '',    
                ReceiveTime = NULL,    
                Remarks = '',    
                ErrorMessage = '',    
                SourceKey = '',    
                DeviceProfileLogKey = @c_DeviceProLogKey,    
                LightCmd = @c_LightCommand,    
                Func = @n_Func,
                EditWho = SUSER_SNAME(),          
                EditDate = GetDATE()
         WHERE IPAddress = @c_DeviceIP    
         AND   DevicePosition = @c_DevicePos  
			AND	Facility = @cFacility 
      END    
    
      UPDATE PTL.PTLTRAN WITH (ROWLOCK) SET    
         STATUS = '1',    
         LightUp = '1'    
      WHERE PTLKey = @n_PTLKey    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @n_Err = 94057    
         SET @c_ErrMsg = '94057 - Update PTLTRAN Fail'    
         SET @n_Continue = 3    
         GOTO RollBackTran    
      END    
    
      COMMIT TRAN isp_PTL_LightUpLoc    
   END    
    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN isp_PTL_LightUpLoc -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
END    
    

GO