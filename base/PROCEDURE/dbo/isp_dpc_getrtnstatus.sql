SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/ 
/* Copyright: IDS                                                             */ 
/* Purpose: BondDPC Integration SP                                            */ 
/*                                                                            */ 
/* Modifications log:                                                         */ 
/*                                                                            */ 
/* Date       Rev  Author     Purposes                                        */ 
/* 2013-02-15 1.0  Shong      Created                                         */
/******************************************************************************/

CREATE PROC [dbo].[isp_DPC_GetRtnStatus] 
(   
    @c_RtnMessage VARCHAR(4000)
   ,@c_RtnStatus  VARCHAR(10) OUTPUT
   ,@c_RtnErrMsg  VARCHAR(1000) OUTPUT 
   ,@c_DPC_RefNo  VARCHAR(20) OUTPUT
)
AS
BEGIN
   IF LEFT(@c_RtnMessage, 3) <> 'STX' AND RIGHT(@c_RtnMessage, 3) <> 'ETX' 
   BEGIN
      SET @c_RtnStatus='NO'
   END
   
   DECLARE @c_Delim CHAR(1)
   
   DECLARE @t_DPCRec TABLE (
      Seqno    INT, 
      ColValue VARCHAR(215)
   )
   
   SET @c_Delim = CHAR(9)
   
   INSERT INTO @t_DPCRec
   SELECT * FROM dbo.fnc_DelimSplit(@c_Delim, @c_RtnMessage)
   
   --SELECT * FROM @t_DPCRec
   
   SELECT @c_RtnStatus = ColValue
   FROM @t_DPCRec
   WHERE Seqno = 4
   
   SELECT @c_RtnErrMsg = ColValue
   FROM @t_DPCRec
   WHERE Seqno = 6   
      
   SELECT @c_DPC_RefNo = ColValue
   FROM @t_DPCRec
   WHERE Seqno = 2   
END

GO