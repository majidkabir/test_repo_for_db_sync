SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: fnc_DPC_GetMsgLength                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: For BondDPC                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 12-03-2013  1.0  Shong       Created.                                */
/************************************************************************/
  
CREATE FUNCTION [dbo].[fnc_DPC_GetMsgLength]   
(@cMessage VARCHAR(4000))  
RETURNS INT  
AS  
BEGIN  
   DECLARE @cLength INT  
     
   IF ISNULL(RTRIM(@cMessage), '') = ''   
      SET @cLength = 0  
   ELSE  
      SET @cLength = LEN(REPLACE(@cMessage, '<TAB>', ' '))  
        
  RETURN @cLength  
END  


GO