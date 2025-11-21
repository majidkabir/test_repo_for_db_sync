SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/   
/* Stored Procedure: isp_PTL_GetRtnStatus                                     */
/* Copyright: IDS                                                             */   
/* Purpose: BondDPC Integration SP                                            */   
/*                                                                            */   
/* Modifications log:                                                         */   
/*                                                                            */   
/* Date       Rev  Author     Purposes                                        */   
/* 2013-02-15 1.0  Shong      Created                                         */  
/******************************************************************************/  
CREATE PROC [PTL].[isp_PTL_GetRtnStatus]   
(     
    @c_RtnMessage VARCHAR(4000)  
   ,@c_RtnStatus  VARCHAR(10) OUTPUT  
   ,@c_RtnErrMsg  VARCHAR(1000) OUTPUT   
   ,@c_PTL_RefNo  VARCHAR(20) OUTPUT  
)  
AS  
BEGIN
   
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- Remove the STX and ETX special character from Return Message
   SET @c_RtnMessage = REPLACE(@c_RtnMessage, CHAR(2), '')
   SET @c_RtnMessage = REPLACE(@c_RtnMessage, CHAR(3), '')
        
   IF LEFT(LTRIM(@c_RtnMessage), 3) <> 'ACK' 
   BEGIN  
      SET @c_RtnStatus='NO'  
   END  
   Else
   BEGIN
      SET @c_RtnStatus =''
   END

      DECLARE @c_Delim CHAR(1)  
     
      DECLARE @t_DPCRec TABLE (  
         Seqno    INT,   
         ColValue VARCHAR(215)  
      )  
     
      SET @c_Delim = '|'  
     
      INSERT INTO @t_DPCRec  
      SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @c_RtnMessage)  
     
      --SELECT * FROM @t_DPCRec  
     
      --SELECT @c_RtnStatus = ColValue  
     -- FROM @t_DPCRec  
     -- WHERE Seqno = 1  

      SELECT @c_PTL_RefNo = ColValue  
      FROM @t_DPCRec  
      WHERE Seqno = 2     
        
      SELECT @c_RtnErrMsg = ColValue  
      FROM @t_DPCRec  
      WHERE Seqno = 3     
END  


GO