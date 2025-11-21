SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*
* @cModeValue
  Summary of Operation Mode Specification Commands, status meaning "light" after key press
   -- m1 Display status
   -- m2 Display status after pressing the CONFIRM button
   -- m3 Display status after pressing the Fn key
   -- m4 Specify CONFIRM button, Fn key
   -- m5 Display status after pressing the Fn key + CONFIRM button
   -- m7 Specify display data after pressing the Fn key
   -- ma Specification for using the DigNum key
   -- me Reverse/Normal display of each SEG (digit) (white digit against black background,
   --    black digit against white background)
   -- mf Barcode display setup for electronic paper display   
 */
 /************************************************************************/
/* Store procedure:                                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 31-03-2021 1.0  yeekung    WMS-18729  Add BAtch light Created        */
/************************************************************************/
CREATE FUNCTION [PTL].[fnc_PTL_GenLightCommand] (
    @cModeValue    VARCHAR(20), -- Operation, Setup, Default
    @nLightModeNo  BIGINT, 
    @cForceColor   NVARCHAR(20) = '',
    @c_DeviceModel NVARCHAR(20) = 'Light')
RETURNS VARCHAR(1000)
AS
BEGIN
   DECLARE
      @c_LightEnabled     CHAR(10)    -- Enabled, Disabled
     ,@c_UpDownLight      VARCHAR(20) -- Off, On, Flash, Flash High
     ,@c_LightMode        VARCHAR(10) -- On, Flash, Flash High
     ,@c_LightColor       VARCHAR(20) -- White, Orange, Purple, Red, LightBlue, Green, Blue
     ,@c_SEG              VARCHAR(20) -- Off, On, Flash, Flash High
     ,@c_BUZ              VARCHAR(20) -- Off, On, Flash, Flash High
     ,@c_FunctionKey      VARCHAR(10) -- Enabled, Disabled
     ,@c_ConfirmButton    VARCHAR(10) -- Enabled, Disabled
     ,@c_DecrementMode    VARCHAR(10) -- Yes, NO
     ,@c_QtyRevisionKey   VARCHAR(20) -- NotUse, Scroll, PlusMinus 
     
     ,@c_LMMCommand       VARCHAR(4000) 
     ,@b_Success          INT   
     ,@n_Err              INT 
     ,@c_ErrMsg           NVARCHAR(215) 
     
   DECLARE @c_ModeArray    VARCHAR(1024)

   --  @c_Stage: Initial, Confirm, FnKey, FnKeyConfirm  
   SET @c_UpDownLight   = 'Flash'
   SET @c_LightMode     = 'On'   -- On, Flash, FlashHigh
   SET @c_LightColor    = 'Blue' -- White, Orange, Purple, Red, LightBlue, Green, Blue
   SET @c_SEG           = 'On'
   SET @c_BUZ           = 'Off'
   SET @c_ConfirmButton = 'On'

   SET @c_QtyRevisionKey = 'Scroll' -- NotUse/ Scroll/ PlusMinus 
     
   DECLARE @c_LightOn         CHAR(4)   
   DECLARE @c_LightOff        CHAR(4)   
   DECLARE @c_LightFlash      CHAR(4)           
   DECLARE @c_FlashHighSpeed  CHAR(4)
   DECLARE @c_LightNoChg      CHAR(4)
   DECLARE @c_NotUse          CHAR(2)
   DECLARE @c_Use             CHAR(2)
   DECLARE @c_NoChange        CHAR(2)
   DECLARE @c_sKey            CHAR(2)
   DECLARE @cModeValueBinary  NVARCHAR(200)
   DECLARE @c_OpInstruction   CHAR(4)
   DECLARE @c_PressConfirm    CHAR(4)
   DECLARE @c_PressFN         CHAR(4)
   DECLARE @c_PressFNConfirm  CHAR(4)
   DECLARE @c_Normal          CHAR(1)
   DECLARE @c_Reverse         CHAR(1)

   SET @c_LightOn        = '0010'
   SET @c_LightOff       = '0001'
   SET @c_LightFlash     = '0011'        
   SET @c_FlashHighSpeed = '0100'
   
   SET @c_NotUse         = '00'
   SET @c_Use            = '01'
   SET @c_NoChange       = '11'
   SET @c_sKey           = '10'

  
   SET @c_OpInstruction  = '0001'
   SET @c_PressConfirm   = '0010'
   SET @c_PressFN        = '0011'
   SET @c_PressFNConfirm = '0101'
   SET @c_Normal         = '0'
   SET @c_Reverse        = '1'

   IF @cModeValue IN ('Operation')
   BEGIN   

      SELECT @c_LightEnabled = L1_Enabled,
               @cModeValueBinary = CASE L1_Status 
                                 WHEN 'Off'        THEN @c_LightOff
                                 WHEN 'On'         THEN @c_LightOn
                                 WHEN 'Flash'      THEN @c_LightFlash
                                 WHEN 'Flash High' THEN @c_FlashHighSpeed
                                 ELSE @c_LightOff
                              END + 
                              PTL.fnc_PTL_GetLEDColorMode(CASE WHEN @cForceColor = '' THEN L1_Color ELSE @cForceColor END,
                              CASE WHEN L1_Status IN ('Flash','Flash High') THEN 'Y' ELSE 'N' END, 
                              CASE WHEN L1_Status IN ('Flash High') THEN 'Y' ELSE 'N' END) +  
                              CASE L1_SEG
                                 WHEN 'Off'        THEN @c_LightOff
                                 WHEN 'On'         THEN @c_LightOn
                                 WHEN 'Flash'      THEN @c_LightFlash
                                 WHEN 'Flash High' THEN @c_FlashHighSpeed
                                 ELSE @c_LightOn
                              END +
                              CASE L1_BUZ
                                 WHEN 'Off'        THEN @c_LightOff
                                 WHEN 'On'         THEN @c_LightOn
                                 WHEN 'Flash'      THEN @c_LightFlash
                                 WHEN 'Flash High' THEN @c_FlashHighSpeed
                                 ELSE @c_LightOff
                              END
      FROM PTL.LightMode AS lm WITH (NOLOCK)
      WHERE lm.LightModeNo = @nLightModeNo
      
      IF RTRIM(@c_LightEnabled) = 'Enabled'
      BEGIN 
         SET @c_ModeArray = 'm1' + 
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4)) +
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 9, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 13, 4)) +
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 17, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 21, 4)) 
      END

      SELECT @c_LightEnabled = L2_Enabled,
               @cModeValueBinary = CASE L2_Status 
                                 WHEN 'Off'        THEN @c_LightOff
                                 WHEN 'On'         THEN @c_LightOn
                                 WHEN 'Flash'      THEN @c_LightFlash
                                 WHEN 'Flash High' THEN @c_FlashHighSpeed
                                 ELSE @c_LightOff
                              END + 
                              PTL.fnc_PTL_GetLEDColorMode(L2_Color,
                              CASE WHEN L2_Status IN ('Flash','Flash High') THEN 'Y' ELSE 'N' END, 
                              CASE WHEN L2_Status IN ('Flash High') THEN 'Y' ELSE 'N' END) +  
                              CASE L2_SEG
                                 WHEN 'Off'        THEN @c_LightOff
                                 WHEN 'On'         THEN @c_LightOn
                                 WHEN 'Flash'      THEN @c_LightFlash
                                 WHEN 'Flash High' THEN @c_FlashHighSpeed
                                 ELSE @c_LightOn
                              END +
                              CASE L2_BUZ
                                 WHEN 'Off'        THEN @c_LightOff
                                 WHEN 'On'         THEN @c_LightOn
                                 WHEN 'Flash'      THEN @c_LightFlash
                                 WHEN 'Flash High' THEN @c_FlashHighSpeed
                                 ELSE @c_LightOff
                              END  
      FROM PTL.LightMode AS lm WITH (NOLOCK)
      WHERE lm.LightModeNo = @nLightModeNo

      IF RTRIM(@c_LightEnabled) = 'Enabled'
      BEGIN       
         SET @c_ModeArray = RTRIM(@c_ModeArray) + 'm2' + 
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4)) +
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 9, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 13, 4)) +
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 17, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 21, 4)) 
      END

      SELECT @c_LightEnabled = L3_Enabled,
               @cModeValueBinary = CASE L3_Status 
                                 WHEN 'Off'        THEN @c_LightOff
                                 WHEN 'On'         THEN @c_LightOn
                                 WHEN 'Flash'      THEN @c_LightFlash
                                 WHEN 'Flash High' THEN @c_FlashHighSpeed
                                 ELSE @c_LightOff
                              END + 
                              PTL.fnc_PTL_GetLEDColorMode(L3_Color,
                              CASE WHEN L3_Status IN ('Flash','Flash High') THEN 'Y' ELSE 'N' END, 
                              CASE WHEN L3_Status IN ('Flash High') THEN 'Y' ELSE 'N' END) +  
                              CASE L3_SEG
                                 WHEN 'Off'        THEN @c_LightOff
                                 WHEN 'On'         THEN @c_LightOn
                                 WHEN 'Flash'      THEN @c_LightFlash
                                 WHEN 'Flash High' THEN @c_FlashHighSpeed
                                 ELSE @c_LightOn
                              END +
                              CASE L3_BUZ
                                 WHEN 'Off'        THEN @c_LightOff
                                 WHEN 'On'         THEN @c_LightOn
                                 WHEN 'Flash'      THEN @c_LightFlash
                                 WHEN 'Flash High' THEN @c_FlashHighSpeed
                                 ELSE @c_LightOff
                              END  
      FROM PTL.LightMode AS lm WITH (NOLOCK)
      WHERE lm.LightModeNo = @nLightModeNo
      
      IF RTRIM(@c_LightEnabled) = 'Enabled'
      BEGIN        
         SET @c_ModeArray = RTRIM(@c_ModeArray) + 'm3' + 
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4)) +
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 9, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 13, 4)) +
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 17, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 21, 4))
      END

      SELECT @c_LightEnabled = L4_Enabled,
               @cModeValueBinary = @c_Use +
                                 CASE L4_FnKeyDecrement
                                 WHEN 'Not use' THEN @c_NotUse
                                 WHEN 'Use' THEN @c_Use
                                 WHEN 'No Change' THEN @c_NoChange
                                 ELSE @c_NotUse 
                                 END +
                                 CASE L4_FnKey
                                 WHEN 'Use' THEN @c_NotUse
                                 WHEN 'Not use' THEN @c_Use
                                 WHEN 'No Change' THEN @c_NoChange
                                 ELSE @c_NotUse
                                 END + 
                                 CASE L4_ConfirmButton
                                 WHEN 'Use' THEN @c_NotUse
                                 WHEN 'Not use' THEN @c_Use
                                 WHEN 'No Change' THEN @c_NoChange
                                 ELSE @c_NotUse
                                 END
      FROM PTL.LightMode As lm WITH (NOLOCK)
      WHERE lm.LightModeNo = @nLightModeNo

      If RTRIM(@c_LightEnabled) = 'Enabled'
      BEGIN
         SET @c_ModeArray = RTRIM(@c_ModeArray) + 'm4' + 
               '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
                     PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4))
      END


      SELECT @c_LightEnabled = L5_Enabled,
               @cModeValueBinary = CASE L5_Status 
                                 WHEN 'Off'        THEN @c_LightOff
                                 WHEN 'On'         THEN @c_LightOn
                                 WHEN 'Flash'      THEN @c_LightFlash
                                 WHEN 'Flash High' THEN @c_FlashHighSpeed
                                 ELSE @c_LightOff
                                 END + 
                                 PTL.fnc_PTL_GetLEDColorMode(L5_Color,
                                    CASE WHEN L5_Status IN ('Flash','Flash High') THEN 'Y' ELSE 'N' END, 
                                    CASE WHEN L5_Status IN ('Flash High') THEN 'Y' ELSE 'N' END) +  
                                 CASE L5_SEG
                                       WHEN 'Off'        THEN @c_LightOff
                                       WHEN 'On'         THEN @c_LightOn
                                       WHEN 'Flash'      THEN @c_LightFlash
                                       WHEN 'Flash High' THEN @c_FlashHighSpeed
                                       ELSE @c_LightOn
                                 END +
                                 CASE L5_BUZ
                                       WHEN 'Off'        THEN @c_LightOff
                                       WHEN 'On'         THEN @c_LightOn
                                       WHEN 'Flash'      THEN @c_LightFlash
                                       WHEN 'Flash High' THEN @c_FlashHighSpeed
                                       ELSE @c_LightOff
                                    END  
      FROM PTL.LightMode AS lm WITH (NOLOCK)
      WHERE lm.LightModeNo = @nLightModeNo
              
      IF RTRIM(@c_LightEnabled) = 'Enabled'
      BEGIN
         SET @c_ModeArray = RTRIM(@c_ModeArray) + 'm5' + 
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4)) +
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 9, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 13, 4)) +
                  '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 17, 4)) +
                        PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 21, 4)) 
      END

      SELECT @c_LightEnabled = ma_Enabled,
               @cModeValueBinary = @c_FlashHighSpeed + @c_NotUse +
                                 CASE ma_qty_rvs
                                 WHEN 'DigNum key' THEN @c_NotUse    --00
                                 WHEN 'Not used'   THEN @c_Use       --01
                                 WHEN 'S/- key'    THEN @c_sKey      --10
                                 WHEN 'No Change'  THEN @c_NoChange  --11
                                 ELSE @c_Use
                                 END
      FROM PTL.LightMode AS lm WITH (NOLOCK)
      WHERE lm.LightModeNo = @nLightModeNo

      IF RTRIM(@c_LightEnabled) = 'Enabled'
      BEGIN
         SET @c_ModeArray = RTRIM(@c_ModeArray) + 'ma' + 
               '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) 
                     + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4))
      END

      SELECT @c_LightEnabled   = me_Enabled,
               @cModeValueBinary = @c_Use + @c_NoChange + 
               CASE me_app_timing
               WHEN '1' THEN @c_OPInstruction
               WHEN '2' THEN @c_PressConfirm
               WHEN '3' THEN @c_PressFN
               WHEN '4' THEN @c_PressFNConfirm
               ELSE @c_OPInstruction
               END + 
               @c_Use + @c_Normal + 
               CASE me_Digit1
               WHEN '0' THEN @c_Normal
               WHEN '1' THEN @c_Reverse
               ELSE @c_Normal
               END + 
               CASE me_Digit2
               WHEN '0' THEN @c_Normal
               WHEN '1' THEN @c_Reverse
               ELSE @c_Normal
               END + 
               CASE me_Digit3
               WHEN '0' THEN @c_Normal
               WHEN '1' THEN @c_Reverse
               ELSE @c_Normal
               END +
               Case me_Digit4
               WHEN '0' THEN @c_Normal
               WHEN '1' THEN @c_Reverse
               ELSE @c_Normal
               END + 
               Case me_Digit5
               WHEN '0' THEN @c_Normal
               WHEN '1' THEN @c_Reverse
               ELSE @c_Normal
               END
      FROM PTL.LightMode AS lm WITH (NOLOCK)
      WHERE lm.LightModeNo = @nLightModeNo

      IF RTRIM(@c_LightEnabled) = 'Enabled'
      BEGIN
         SET @c_ModeArray = RTRIM(@c_ModeArray) + 'me' + 
               '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
                     + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4)) +
               '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 9, 4)) +
                     + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 13, 4)) 
      END
      IF @c_DeviceModel='LIGHT'
      BEGIN
         SET @c_ModeArray = 'PP5050000' + RTRIM(@c_ModeArray)  
        -- SET @c_ModeArray = 'PP2A0600' + RTRIM(@c_ModeArray)                                                                                       
      END

      IF @c_DeviceModel='BATCH'
      BEGIN
          SET @c_ModeArray ='PQ1'+'00'+'m1$31$13$21'+'AF101' +'@cPOS'+'A'--+RTRIM(@c_ModeArray) 
      END

   END

   ELSE IF @cModeValue ='Default'
   BEGIN
      SET @c_ModeArray = 'm1$33$33$23' 
                       + 'm2$11$11$11' 
                       + 'm3$22$22$21' 
                       + 'm4$40'       
                       + 'm5$11$11$11'
                          
      SET @c_ModeArray = 'PP5050000' + RTRIM(@c_ModeArray)
   END

   ELSE IF @cModeValue ='Setup'
   BEGIN
      SELECT @c_LightEnabled = L1_Enabled,
                @cModeValueBinary = CASE L1_Status 
                                    WHEN 'Off'        THEN @c_LightOff
                                    WHEN 'On'         THEN @c_LightOn
                                    WHEN 'Flash'      THEN @c_LightFlash
                                    WHEN 'Flash High' THEN @c_FlashHighSpeed
                                    ELSE @c_LightOff
                               END + 
                               PTL.fnc_PTL_GetLEDColorMode(L1_Color,
                                 CASE WHEN L1_Status IN ('Flash','Flash High') THEN 'Y' ELSE 'N' END, 
                                 CASE WHEN L1_Status IN ('Flash High') THEN 'Y' ELSE 'N' END) +  
                               CASE L1_SEG
                                    WHEN 'Off'        THEN @c_LightOff
                                    WHEN 'On'         THEN @c_LightOn
                                    WHEN 'Flash'      THEN @c_LightFlash
                                    WHEN 'Flash High' THEN @c_FlashHighSpeed
                                    ELSE @c_LightOn
                               END +
                               CASE L1_BUZ
                                    WHEN 'Off'        THEN @c_LightOff
                                    WHEN 'On'         THEN @c_LightOn
                                    WHEN 'Flash'      THEN @c_LightFlash
                                    WHEN 'Flash High' THEN @c_FlashHighSpeed
                                    ELSE @c_LightOff
                               END
                                 
      FROM PTL.LightMode AS lm WITH (NOLOCK)
      WHERE lm.LightModeNo = @nLightModeNo
      
      IF RTRIM(@c_LightEnabled) = 'Enabled'
      BEGIN 
         SET @c_ModeArray = 'm1' + 
                '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
                      PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4)) +
                '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 9, 4)) +
                      PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 13, 4)) +
                '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 17, 4)) +
                      PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 21, 4)) 
      END

         SELECT @c_LightEnabled = L2_Enabled,
                @cModeValueBinary = CASE L2_Status 
                                    WHEN 'Off'        THEN @c_LightOff
                                    WHEN 'On'         THEN @c_LightOn
                                    WHEN 'Flash'      THEN @c_LightFlash
                                    WHEN 'Flash High' THEN @c_FlashHighSpeed
                                    ELSE @c_LightOff
                               END + 
                               PTL.fnc_PTL_GetLEDColorMode(L2_Color,
                                 CASE WHEN L2_Status IN ('Flash','Flash High') THEN 'Y' ELSE 'N' END, 
                                 CASE WHEN L2_Status IN ('Flash High') THEN 'Y' ELSE 'N' END) +  
                               CASE L2_SEG
                                    WHEN 'Off'        THEN @c_LightOff
                                    WHEN 'On'         THEN @c_LightOn
                                    WHEN 'Flash'      THEN @c_LightFlash
                                    WHEN 'Flash High' THEN @c_FlashHighSpeed
                                    ELSE @c_LightOn
                               END +
                               CASE L2_BUZ
                                    WHEN 'Off'        THEN @c_LightOff
                                    WHEN 'On'         THEN @c_LightOn
                                    WHEN 'Flash'      THEN @c_LightFlash
                                    WHEN 'Flash High' THEN @c_FlashHighSpeed
                                    ELSE @c_LightOff
                               END  
      FROM PTL.LightMode AS lm WITH (NOLOCK)
      WHERE lm.LightModeNo = @nLightModeNo

      IF RTRIM(@c_LightEnabled) = 'Enabled'
      BEGIN       
         SET @c_ModeArray = RTRIM(@c_ModeArray) + 'm2' + 
                '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
                      PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4)) +
                '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 9, 4)) +
                      PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 13, 4)) +
                '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 17, 4)) +
                      PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 21, 4)) 
      END

         SELECT @c_LightEnabled = L3_Enabled,
                @cModeValueBinary = CASE L3_Status 
                                    WHEN 'Off'        THEN @c_LightOff
                                    WHEN 'On'         THEN @c_LightOn
                                    WHEN 'Flash'      THEN @c_LightFlash
                                    WHEN 'Flash High' THEN @c_FlashHighSpeed
                                    ELSE @c_LightOff
                               END + 
                               PTL.fnc_PTL_GetLEDColorMode(L3_Color,
                                 CASE WHEN L3_Status IN ('Flash','Flash High') THEN 'Y' ELSE 'N' END, 
                                 CASE WHEN L3_Status IN ('Flash High') THEN 'Y' ELSE 'N' END) +  
                               CASE L3_SEG
                                    WHEN 'Off'        THEN @c_LightOff
                                    WHEN 'On'         THEN @c_LightOn
                                    WHEN 'Flash'      THEN @c_LightFlash
                                    WHEN 'Flash High' THEN @c_FlashHighSpeed
                                    ELSE @c_LightOn
                               END +
                               CASE L3_BUZ
                                    WHEN 'Off'        THEN @c_LightOff
                                    WHEN 'On'         THEN @c_LightOn
                                    WHEN 'Flash'      THEN @c_LightFlash
                                    WHEN 'Flash High' THEN @c_FlashHighSpeed
                                    ELSE @c_LightOff
                               END  
         FROM PTL.LightMode AS lm WITH (NOLOCK)
         WHERE lm.LightModeNo = @nLightModeNo
      
         IF RTRIM(@c_LightEnabled) = 'Enabled'
         BEGIN        
            SET @c_ModeArray = RTRIM(@c_ModeArray) + 'm3' + 
                   '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
                         PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4)) +
                   '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 9, 4)) +
                         PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 13, 4)) +
                   '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 17, 4)) +
                         PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 21, 4))
         END

         SELECT @c_LightEnabled = L4_Enabled,
                @cModeValueBinary = @c_Use +
                                    CASE L4_FnKeyDecrement
                                    WHEN 'Not use' THEN @c_NotUse
                                    WHEN 'Use' THEN @c_Use
                                    WHEN 'No Change' THEN @c_NoChange
                                    ELSE @c_NotUse 
                                    END +
                                    CASE L4_FnKey
                                    WHEN 'Use' THEN @c_NotUse
                                    WHEN 'Not use' THEN @c_Use
                                    WHEN 'No Change' THEN @c_NoChange
                                    ELSE @c_NotUse
                                    END + 
                                    CASE L4_ConfirmButton
                                    WHEN 'Use' THEN @c_NotUse
                                    WHEN 'Not use' THEN @c_Use
                                    WHEN 'No Change' THEN @c_NoChange
                                    ELSE @c_NotUse
                                    END
         FROM PTL.LightMode As lm WITH (NOLOCK)
         WHERE lm.LightModeNo = @nLightModeNo

         If RTRIM(@c_LightEnabled) = 'Enabled'
         BEGIN
            SET @c_ModeArray = RTRIM(@c_ModeArray) + 'm4' + 
                '$' + PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 1, 4)) +
                      PTL.fnc_PTL_ConvertBinaryToHex(SUBSTRING(@cModeValueBinary, 5, 4))
         END


         SELECT @c_LightEnabled = L5_Enabled,
                @cModeValueBinary = CASE L5_Status 
                                    WHEN 'Off'        THEN @c_LightOff
                                    WHEN 'On'         THEN @c_LightOn
                                    WHEN 'Flash'      THEN @c_LightFlash
                                    WHEN 'Flash High' THEN @c_FlashHighSpeed
                                    ELSE @c_LightOff
                                    END + 
                                    PTL.fnc_PTL_GetLEDColorMode(L5_Color,
                                      CASE WHEN L5_Status IN ('Flash','Flash High') THEN 'Y' ELSE 'N' END, 
                                      CASE WHEN L5_Status IN ('Flash High') THEN 'Y' ELSE 'N' END) +  
                                    CASE L5_SEG
                                         WHEN 'Off'        THEN @c_LightOff
                                         WHEN 'On'         THEN @c_LightOn
                                         WHEN 'Flash'      THEN @c_LightFlash
                                         WHEN 'Flash High' THEN @c_FlashHighSpeed
                                         ELSE @c_LightOn
                                    END +
                                    CASE L5_BUZ
                                         WHEN 'Off'        THEN @c_LightOff
                                         WHEN 'On'         THEN @c_LightOn
                                         WHEN 'Flash'      THEN @c_LightFlash
                                         WHEN 'Flash High' THEN @c_FlashHighSpeed
                                         ELSE @c_LightOff
                                    END  
      FROM PTL.LightMode AS lm WITH (NOLOCK)
      WHERE lm.LightModeNo = @nLightModeNo 

      SET @c_ModeArray = 'M' + RTRIM(@c_ModeArray)                                                                                        
   END
   ELSE IF @cModeValue ='TerminateModule' --alex01
   BEGIN
      SET @c_ModeArray = 'D'
   END
   ELSE IF @cModeValue ='TowerLightT' --(ChewKP01) WMS-3962
   BEGIN
      SET @c_ModeArray = 'T'
   END

   RETURN @c_ModeArray 
END

GO