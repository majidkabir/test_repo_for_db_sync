SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*****************************************************************************************/
/* Function       : fnc_GetParamValueFromString                                          */
/* Copyright      : LFL                                                                  */
/*                                                                                       */
/* Purpose: WMS-5745 Parse the parameter value from string by stored                     */
/*          proc parameter name.                                                         */
/*          Can pass in default value if can't get the value                             */
/*                                                                                       */
/* Usage: dbo.fnc_GetParamValueFromString ('@c_sku','@c_sku=ABC @c_storerkey=LFL','XYZ') */
/*        If the value contain @ should put @@ instead to avoid symbol conflic           */
/*                                                                                       */
/* Modifications log:                                                                    */
/*                                                                                       */
/* Date         Rev  Author     Purposes                                                 */
/*****************************************************************************************/

CREATE FUNCTION [dbo].[fnc_GetParamValueFromString]
(
@c_ParameterName NVARCHAR(50),
@c_StringData NVARCHAR(4000),
@c_DefaulValue NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
BEGIN	
   DECLARE  @c_ParamNamePos INT, @c_EqualPos INT, @c_AliasPos INT, @c_ParameterValue_Rtn NVARCHAR(1000)
   
   SELECT @c_ParameterValue_Rtn = ''
   
   SELECT @c_StringData = REPLACE(@c_StringData,'@@','~')
   
   SELECT @c_ParamNamePos = CHARINDEX(@c_ParameterName, @c_StringData, 1)
   
   --Make sure get the correct param name if have more than 1 simular name. e.g. @testing=12, @test=34  when searh test avoid wrongly get testing
   WHILE @c_ParamNamePos > 0 AND SUBSTRING(@c_StringData, @c_ParamNamePos + LEN(@c_ParameterName), 1) NOT IN(' ','=')
   BEGIN
   	  SELECT @c_ParamNamePos = CHARINDEX(@c_ParameterName, @c_StringData, @c_ParamNamePos + LEN(@c_ParameterName))
   END
   
   IF @c_ParamNamePos > 0 
     SELECT @c_EqualPos = CHARINDEX('=',@c_StringData, @c_ParamNamePos + LEN(RTRIM(@c_ParameterName)))
     
   IF @c_EqualPos > 0
   BEGIN
     SELECT @c_AliasPos = CHARINDEX('@', @c_StringData, @c_EqualPos + 1)  
     
     IF @c_AliasPos = 0
        SET @c_AliasPos = LEN(@c_StringData) + 1
   END
       
   IF @c_AliasPos > 0
   BEGIN
     SELECT @c_ParameterValue_Rtn = SUBSTRING(@c_StringData, @c_EqualPos + 1, @c_AliasPos - (@c_EqualPos + 1))     
     SELECT @c_ParameterValue_Rtn = REPLACE(@c_ParameterValue_Rtn,'~','@')     
   END  
   
   IF ISNULL(@c_ParameterValue_Rtn, '') = '' AND ISNULL(@c_DefaulValue, '') <> '' AND ISNULL(@c_AliasPos,0) = 0
      SET @c_ParameterValue_Rtn = @c_DefaulValue
           
   RETURN LTRIM(RTRIM(@c_ParameterValue_Rtn)) 
END

GO