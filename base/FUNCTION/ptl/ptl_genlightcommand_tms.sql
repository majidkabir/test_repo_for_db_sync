SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

--@c_DeviceStatus if status is 1 then light on else off light
--@c_ProductCode one TMS light got specific product code

CREATE FUNCTION [PTL].[PTL_GenLightCommand_TMS] (    
    @c_DeviceID     NVARCHAR(20),    
    @c_DevicePos    NVARCHAR(20),    
    @c_DeviceStatus NVARCHAR(1)   )    
RETURNS VARCHAR(1000)    
AS    
BEGIN

   DECLARE @c_ModeArray NVARCHAR(1000),
           @c_ProductCode NVARCHAR(100),
           @c_AreaZone  NVARCHAR(2)

   SET @c_AreaZone = SUBSTRING(@c_DevicePos,1,1)

   SELECT @c_ProductCode=udf02
   from codelkup (NOLOCK)
   where listname='TCPCLIENT'
   AND  code=@c_DeviceID
   and  short='light'

   SET @c_ModeArray='{'+@c_ProductCode+'|'
   
   IF (@c_DeviceStatus='0')
   BEGIN
      SET @c_ModeArray='{'+@c_ProductCode+'| '+@c_AreaZone+'*#0}'
   END
   ELSE IF  (@c_DeviceStatus='1')
   BEGIN
      SET @c_ModeArray='{'+@c_ProductCode+'| '+@c_DevicePos+'#1}'
   END

   RETURN @c_ModeArray     
END 

GO