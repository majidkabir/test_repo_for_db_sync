SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Proc    : isp_RDTperfInfo                                        */
/* Creation Date  : 5 Jul 2012                                             */
/* Copyright      : Li & Fung                                              */
/* Written by     : KHLim                                                  */
/*                                                                         */
/* Purpose        : Get RDT Performance Info for daily alert               */
/*                                                                         */
/*                                                                         */
/* Usage :                                                                 */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By      : Back-end job                                           */
/*                                                                         */
/* PVCS Version   : 1.1                                                    */
/*                                                                         */
/* Version        : 5.4                                                    */
/*                                                                         */
/* Data Modifications :                                                    */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver  Purposes                                      */
/* 16-Feb-2015 KHLim    1.1  output SP name to remote server (KHLim01)     */
/***************************************************************************/

CREATE PROC [RDT].[isp_RDTperfInfo]
   @nF   int,
   @nI   int,
   @nO   int,
   @cLM  NVARCHAR(100) OUTPUT,
   @dLM  datetime    OUTPUT
   ,@cSPout NVARCHAR(100) = '' OUTPUT  --KHLim01
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS ON
   SET ANSI_WARNINGS ON


   SELECT TOP 1
      @dLM = o.modify_date, 
      @cLM = RTRIM(LTRIM(SUBSTRING( definition,
                                 LEN(definition)-CHARINDEX(' */',REVERSE(definition),CHARINDEX('CORP ETAERC',REVERSE(definition)))+1,
                                 65)))
   FROM sys.sql_modules AS sm
   JOIN sys.objects AS o ON sm.object_id = o.object_id
   WHERE o.name = ( SELECT TOP 1 StoredProcName FROM RDT.RDTMsg WITH (NOLOCK) 
                  WHERE Message_ID = @nF AND Lang_Code = 'ENG' )

   SELECT        TOP 1 @cSPout = StoredProcName FROM RDT.RDTMsg WITH (NOLOCK) --KHLim01
                  WHERE Message_ID = @nF AND Lang_Code = 'ENG'

END

Grant Execute on  RDT.isp_RDTperfInfo to NSQL

GO