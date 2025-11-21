SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/   
/* Stored Procedure: isp_WCS_GetRtnStatus                                     */
/* Copyright: IDS                                                             */   
/* Purpose:  Integration SP                                                   */   
/*                                                                            */   
/* Modifications log:                                                         */   
/*                                                                            */   
/* Date       Rev  Author     Purposes                                        */   
/* 2018-06-08 1.0  ChewKP     Created                                         */  
/******************************************************************************/  
CREATE PROC [RDT].[isp_WCS_GetRtnStatus]   
(     
    @c_RtnMessage VARCHAR(4000)  
   ,@c_RtnStatus  VARCHAR(10) OUTPUT  
   ,@c_RtnErrMsg  VARCHAR(1000) OUTPUT   
   
)  
AS  
BEGIN
   
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cWCSErr NVARCHAR(1)
   
   -- Remove the STX and ETX special character from Return Message
   --SET @c_RtnMessage = REPLACE(@c_RtnMessage, CHAR(2), '')
   --SET @c_RtnMessage = REPLACE(@c_RtnMessage, CHAR(3), '')
        --PRINt 'adsfasdfasfda'
   SET @cWCSErr  = SUBSTRING(@c_RtnMessage, 13, 1)

   IF @cWCSErr = '2'
   BEGIN  
      SET @c_RtnStatus='NO'  
   END  
   Else
   BEGIN
      SET @c_RtnStatus =''
   END
   
END  


GO