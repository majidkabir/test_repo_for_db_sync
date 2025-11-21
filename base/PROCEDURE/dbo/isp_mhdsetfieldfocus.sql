SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: isp_MHDSetFieldFocus                                */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Set field focus on lottable01                               */
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2014-06-09 1.0  James    SOS308816 Created                           */    
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_MHDSetFieldFocus]    
   @nMobile         INT,      
   @c_LotLabel01    NVARCHAR( 20),     
   @c_LotLabel02    NVARCHAR( 20),    
   @c_LotLabel03    NVARCHAR( 20),     
   @c_LotLabel04    NVARCHAR( 20),     
   @c_LotLabel05    NVARCHAR( 20), 
   @c_Lottable01    NVARCHAR( 18),       
   @c_Lottable02    NVARCHAR( 18),       
   @c_Lottable03    NVARCHAR( 18),       
   @c_Lottable04    NVARCHAR( 16),       
   @c_Lottable05    NVARCHAR( 16),       
   @n_ErrNo         INT           OUTPUT,   
   @c_ErrMsg        NVARCHAR( 20) OUTPUT 
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   EXEC rdt.rdtSetFocusField @nMobile, 2 -- Lottable01  

QUIT:    
END -- End Procedure    

GO