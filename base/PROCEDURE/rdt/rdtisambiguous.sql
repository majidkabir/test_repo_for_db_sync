SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtIsAmbiguous                                      */
/* Written By     : James                                               */
/*                                                                      */
/* Purpose: Check if a qty is ambiguous to do a move on pallet/loc      */
/* For example:                                                         */
/* Total Qty=10; Avail Qty: 5; Alloc Qty: 3; Pick Qty: 2                */
/* Rules: Qty on pallet cannot move partially on avail/alloc/pick.      */
/* Qty valid to move: 2, 3, 5, 7, 8 & 10                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 28-May-2015  1.0  James      Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdtIsAmbiguous]( 
    @nA                 INT    
   ,@nB                 INT
   ,@nC                 INT 
   ,@nQty2Check         INT 
   ,@b_Success          INT            OUTPUT  
   ,@n_ErrNo            INT            OUTPUT  
   ,@c_ErrMsg           NVARCHAR(20)   OUTPUT 
) AS 
BEGIN

   DECLARE @b_debug  INT

   SET @b_debug = 0

   IF OBJECT_ID('tempdb..#TMP_ABC') IS NOT NULL   
      DROP TABLE #TMP_ABC

   -- (james02)
   CREATE TABLE #TMP_ABC  
         (  A     INT   DEFAULT (0)   
         ,  B     INT   DEFAULT (0)   
         ,  C     INT   DEFAULT (0)   
         ,  AB    INT   DEFAULT (0)   
         ,  AC    INT   DEFAULT (0)   
         ,  BC    INT   DEFAULT (0)   
         ,  ABC   INT   DEFAULT (0)            
         )  

   INSERT INTO #TMP_ABC (A, B, C, AB, AC, BC, ABC)   VALUES (@nA, @nB, @nC, (@nA + @nB), (@nA + @nC), (@nB + @nC), (@nA + @nB + @nC))

   IF @b_debug = 1
   BEGIN
      SELECT '@nA', @nA, '@nB', @nB, '@nC', @nC, '@nQty2Check', @nQty2Check
      SELECT * FROM #TMP_ABC
   END

   IF EXISTS ( SELECT 1 FROM #TMP_ABC WHERE @nQty2Check IN (A, B, C, AB, AC, BC, ABC))
      SET @b_Success = 1 -- true
   ELSE
      SET @b_Success = 0 -- false
END

GO