SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Function       : fncConvUOM                                          */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Convert QTY based on FromUOM and ToUOM                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Rev  Author     Purposes                                */  
/* 2019-09-26   1.0  Shong    Created                                   */  
/************************************************************************/  
  
CREATE FUNCTION [WM].[fncConvUOM] (   
   @cPackKey NVARCHAR( 15),  
   @cFromQTY NVARCHAR( 20),  
   @cFromUOM NVARCHAR( 1),  
   @cToUOM   NVARCHAR( 1)  
) RETURNS INT AS  
BEGIN  
   
 IF Isnumeric(@cFromQTY) <> 1  
 BEGIN  
  GOTO FAIL  
 END  
  
   DECLARE @nEaQTY  INT  
   DECLARE @nDivQTY INT  
   DECLARE @nToQTY  INT  
   DECLARE @nFromQTY Float  
  
   SELECT @nEaQTY  = 0  
   SELECT @nDivQTY = 0  
   SELECT @nToQTY  = 0  
  
 SELECT @nFromQTY = CONVERT(float,@cFromQTY)  
  
   SELECT   
      @nEaQTY = CASE   
            WHEN PACK.PACKUOM1 = @cFromUOM AND PACK.CaseCnt > 0 THEN @nFromQTY * PACK.CaseCnt   
            WHEN PACK.PACKUOM2 = @cFromUOM AND PACK.InnerPack > 0 THEN @nFromQTY * PACK.InnerPack   
            WHEN PACK.PACKUOM3 = @cFromUOM OR ISNULL(@cFromUOM,'') = '' THEN @nFromQTY        
            WHEN PACK.PACKUOM4 = @cFromUOM AND PACK.Pallet > 0 THEN @nFromQTY * PACK.Pallet    
            WHEN PACK.PACKUOM5 = @cFromUOM AND PACK.Cube > 0 THEN @nFromQTY * PACK.Cube    
            WHEN PACK.PACKUOM6 = @cFromUOM AND PACK.GrossWgt > 0 THEN @nFromQTY * PACK.GrossWgt   
            WHEN PACK.PACKUOM7 = @cFromUOM AND PACK.NetWgt > 0 THEN @nFromQTY * PACK.NetWgt   
            WHEN PACK.PACKUOM8 = @cFromUOM AND PACK.OtherUnit1 > 0 THEN @nFromQTY * PACK.OtherUnit1   
            WHEN PACK.PACKUOM9 = @cFromUOM AND PACK.OtherUnit2 > 0 THEN @nFromQTY * PACK.OtherUnit2               
            ELSE @nFromQTY END,  
      @nDivQTY =   
         CASE   
            WHEN PACK.PACKUOM1 = @cToUOM AND PACK.CaseCnt > 0 THEN PACK.CaseCnt    
            WHEN PACK.PACKUOM2 = @cToUOM AND PACK.InnerPack > 0 THEN PACK.InnerPack    
            WHEN PACK.PACKUOM3 = @cToUOM THEN 1        
            WHEN PACK.PACKUOM4 = @cToUOM AND PACK.Pallet > 0 THEN PACK.Pallet     
            WHEN PACK.PACKUOM5 = @cToUOM AND PACK.Cube > 0 THEN PACK.Cube     
            WHEN PACK.PACKUOM6 = @cToUOM AND PACK.GrossWgt > 0 THEN PACK.GrossWgt    
            WHEN PACK.PACKUOM7 = @cToUOM AND PACK.NetWgt > 0 THEN PACK.NetWgt    
            WHEN PACK.PACKUOM8 = @cToUOM AND PACK.OtherUnit1 > 0 THEN PACK.OtherUnit1    
            WHEN PACK.PACKUOM9 = @cToUOM AND PACK.OtherUnit2 > 0 THEN PACK.OtherUnit2     
                 ELSE 1  
            END                           
   FROM dbo.PACK PACK (NOLOCK)   
   WHERE Pack.PackKey = @cPackKey   
  
   IF @nEaQTY IS NULL OR @nDivQTY IS NULL OR @nDivQTY = 0  
      GOTO FAIL  
  
   SELECT @nToQTY = CONVERT(INT,(@nEaQTY / @nDivQTY))  
  
   RETURN @nToQTY  
  
FAIL:  
   RETURN 0  
END  

GO