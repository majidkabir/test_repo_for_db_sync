SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE   FUNCTION [PTL].[fnc_PTL_GetLEDColorMode]
(
  @c_Color     VARCHAR(20),
  @c_Flash     CHAR(1) ,
  @c_HighSpeed CHAR(1)
)
RETURNS CHAR(12)
AS
BEGIN
    DECLARE @c_LightOn            CHAR(4)
           ,@c_LightOff           CHAR(4)
           ,@c_LightFlash         CHAR(4)
           ,@c_FlashHighSpeed     CHAR(4)
           ,@c_LED0               CHAR(4)
           ,@c_LED1               CHAR(4)
           ,@c_LED2               CHAR(4)
           ,@c_ReturnColor        CHAR(12)

    SET @c_LightOn    = '0010'
    SET @c_LightOff   = '0001'
    SET @c_LightFlash = '0011'
    SET @c_FlashHighSpeed = '0100'

    SET @c_LightOn = CASE WHEN @c_Flash = 'Y' AND @c_HighSpeed = 'Y'
                               THEN @c_FlashHighSpeed
                          WHEN @c_Flash = 'Y' AND @c_HighSpeed = 'N'
                               THEN @c_LightFlash
                          ELSE '0010'
                     END

    IF @c_Color = 'Red'
    BEGIN
       SET @c_LED2 = @c_LightOff
       SET @c_LED1 = @c_LightOff
       SET @c_LED0 = @c_LightOn
    END
    ELSE IF @c_Color = 'Green'
    BEGIN
       SET @c_LED2 = @c_LightOff
       SET @c_LED1 = @c_LightOn
       SET @c_LED0 = @c_LightOff
    END
    ELSE IF @c_Color = 'Orange'
    BEGIN
       SET @c_LED2 = @c_LightOff
       SET @c_LED1 = @c_LightOn
       SET @c_LED0 = @c_LightOn
    END
    ELSE IF @c_Color = 'Blue'
    BEGIN
       SET @c_LED2 = @c_LightOn
       SET @c_LED1 = @c_LightOff
       SET @c_LED0 = @c_LightOff
    END
    ELSE IF @c_Color = 'Purple'
    BEGIN
       SET @c_LED2 = @c_LightOn
       SET @c_LED1 = @c_LightOff
       SET @c_LED0 = @c_LightOn
    END
    ELSE IF @c_Color = 'LightBlue'
    BEGIN
       SET @c_LED2 = @c_LightOn
       SET @c_LED1 = @c_LightOn
       SET @c_LED0 = @c_LightOff
    END
    ELSE IF @c_Color = 'White'
    BEGIN
       SET @c_LED2 = @c_LightOn
       SET @c_LED1 = @c_LightOn
       SET @c_LED0 = @c_LightOn
    END
    ELSE
    BEGIN
       SET @c_LED2 = @c_LightOff
       SET @c_LED1 = @c_LightOff
       SET @c_LED0 = @c_LightOff
    END


    SET @c_ReturnColor = @c_LED0 + @c_LED1 + @c_LED2
    RETURN @c_ReturnColor
END

GO