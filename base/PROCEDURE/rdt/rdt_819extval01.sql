SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_819ExtVal01                                     */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Jack Will cart picking check orders validity                */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2016-09-15  1.0  James    SOS370883 - Created                        */    
/************************************************************************/    
CREATE PROC [RDT].[rdt_819ExtVal01] (    
   @nMobile    INT, 
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),  
   @nStep      INT, 
   @nInputKey  INT, 
   @cFacility  NVARCHAR( 5),  
   @cStorerKey NVARCHAR( 15), 
   @cLight     NVARCHAR( 1),   
   @cDPLKey    NVARCHAR( 10), 
   @cCartID    NVARCHAR( 10), 
   @cPickZone  NVARCHAR( 10), 
   @cMethod    NVARCHAR( 10), 
   @cPickSeq   NVARCHAR( 1), 
   @cLOC       NVARCHAR( 10), 
   @cSKU       NVARCHAR( 20), 
   @cToteID    NVARCHAR( 20), 
   @nQTY       INT,           
   @cNewToteID NVARCHAR( 20), 
   @nErrNo     INT            OUTPUT, 
   @cErrMsg    NVARCHAR( 20)  OUTPUT  
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cOrderKey         NVARCHAR( 10),
           @cCustomSQL        NVARCHAR( MAX),
           @cStartSQL         NVARCHAR( MAX),
           @cExcludeSQL       NVARCHAR( MAX),
           @cEndSQL           NVARCHAR( MAX),
           @cExecStatements   NVARCHAR( MAX),
           @cExecArguments    NVARCHAR( MAX)
   
     
   /*
      CODE = æ1Æ, DESCRIPTION = æEcomm MultisÆ, SHORT = æ1Æ
 	   CODE = æ2Æ, DESCRIPTION = æEcomm SinglesÆ, SHORT = æ2Æ
 	   CODE = æ3Æ, DESCRIPTION = æAll EcommÆ, SHORT = æ3Æ
 	   CODE = æ4Æ, DESCRIPTION = æStore SinglesÆ, SHORT = æ4Æ
 	   CODE = æ5Æ, DESCRIPTION = æStore Singles and Ecomm MultisÆ, SHORT = 		æ5Æ
 	   CODE = æ6Æ, DESCRIPTION = æAll SinglesÆ, SHORT = æ6Æ
 	   CODE = æ7Æ, DESCRIPTION = æAll Singles and Ecomm MultisÆ, SHORT = æ7Æ

    	Only select orders that 
    	1. can be fully picked in 1 trolley zone
    	2. not partially picked before
    	3. cancel task for orders if not start yet
   */

   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF @nStep = 1  -- CART ID, PICKZONE, METHOD, PICKSEQ
      BEGIN
                         
         IF OBJECT_ID('tempdb..#t_orderkey') IS NOT NULL
            DROP TABLE #t_orderkey

         CREATE TABLE #t_orderkey (OrderKey NVARCHAR( 10), TZone NVARCHAR( 10))

         -- Get Orderkey
         SET @cStartSQL = 
         ' INSERT INTO #t_orderkey (OrderKey, TZone)' + 
         ' SELECT O.OrderKey, ISNULL( CLK.Long, '''') ' + 
         ' FROM dbo.Orders O WITH (NOLOCK) ' + 
         ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( O.OrderKey = PD.OrderKey) ' + 
         ' JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC) ' + 
         ' JOIN dbo.CodeLkUp CLK WITH (NOLOCK) ON ( LOC.PickZone = CLK.Code AND O.StorerKey = CLK.StorerKey) ' + 
         ' WHERE O.StorerKey = @cStorerKey ' + 
         ' AND   O.Status IN (''1'', ''2'') ' + -- Only select orders that not yet start picking, either partial or fully alloc
         ' AND   PD.Status = ''0'' ' + 
         ' AND   CLK.ListName = ''WCSSTATION'' ' +
         ' AND   ISNULL( CLK.Long, '''') <> '''' ' +
--         ' AND   LOC.LocationCategory = ''PPA'' ' +
         ' AND   LOC.LocationType = ''PICK'' ' +
         ' AND   LOC.Facility = @cFacility ' 

         -- Must exclude those assign orders
         SET @cExcludeSQL = 
         ' AND   NOT EXISTS ( SELECT 1 FROM rdt.rdtPTLCartLog PTL WITH (NOLOCK) ' +
         '                    WHERE O.OrderKey = PTL.OrderKey ' +
         '                    AND   O.StorerKey = PTL.StorerKey) ' 
         
         -- Exclude those orders which already has task and pick in progress
         SET @cExcludeSQL = @cExcludeSQL + 
         ' AND   NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK) ' +
         '                    WHERE PD.TaskDetailKey = TD.TaskDetailKey ' +
         '                    AND   TD.Status > ''0'') '           

         IF @cPickSeq IN ( '1', '2', '3')
         BEGIN
            IF @cPickSeq = '1'
               SET @cCustomSQL = ' AND   USERDEFINE01 LIKE ''MULTI%'' '

            IF @cPickSeq = '2'
               SET @cCustomSQL = ' AND   USERDEFINE01 LIKE ''SINGLE%'' '

            IF @cPickSeq = '3'
               SET @cCustomSQL = ' AND   USERDEFINE01 <> '''' '

            -- Only select orders that can be fulfilled by 1 trolley zone only
            SET @cEndSQL = 
            ' GROUP BY O.OrderKey, ISNULL( CLK.Long, '''') '
         END

         IF @cPickSeq = '4'   -- STORE SINGLES
         BEGIN
            SET @cCustomSQL = ' AND   O.Type LIKE ''STORE%'' '

            -- Only select orders that can be fulfilled by 1 trolley zone only
            SET @cEndSQL = 
            ' GROUP BY O.OrderKey, ISNULL( CLK.Long, '''') ' +
            ' HAVING ISNULL( SUM( PD.QTY), 0) = 1 '
         END

         IF @cPickSeq = '5'   -- STORE SINGLES & ECOMM MULTIS
         BEGIN
            SET @cCustomSQL = ' ' 

            -- Only select orders that can be fulfilled by 1 trolley zone only
            SET @cEndSQL = 
            ' GROUP BY O.OrderKey, ISNULL( CLK.Long, ''''), O.Type, USERDEFINE01 ' +
            ' HAVING ( O.Type LIKE ''STORE%'' AND ISNULL( SUM( PD.QTY), 0) = 1) OR ' + 
            '        USERDEFINE01 LIKE ''MULTI%'' '
         END

         IF @cPickSeq = '6'   -- ALL SINGLES
         BEGIN
            SET @cCustomSQL = ' ' 

            -- Only select orders that can be fulfilled by 1 trolley zone only
            SET @cEndSQL = 
            ' GROUP BY O.OrderKey, ISNULL( CLK.Long, '''') ' +
            ' HAVING ISNULL( SUM( PD.QTY), 0) = 1 '
         END

         IF @cPickSeq = '7'   -- ALL SINGLES & ECOMM MULTIS
         BEGIN
            SET @cCustomSQL = ' ' 

            -- Only select orders that can be fulfilled by 1 trolley zone only
            SET @cEndSQL = 
            ' GROUP BY O.OrderKey, ISNULL( CLK.Long, ''''), USERDEFINE01 ' +
            ' HAVING ISNULL( SUM( PD.QTY), 0) = 1 OR ' +
            '        USERDEFINE01 LIKE ''MULTI%'' '
         END

         SET @cExecStatements = @cStartSQL + @cCustomSQL + @cExcludeSQL + @cEndSQL

         SET @cExecArguments =  N'@cStorerKey            NVARCHAR(15), ' +
                                 '@cFacility             NVARCHAR(5)   ' 

         EXEC sp_ExecuteSql @cExecStatements
                           ,@cExecArguments
                           ,@cStorerKey
                           ,@cFacility

         IF OBJECT_ID('tempdb..#t_orderkey1') IS NOT NULL
            DROP TABLE #t_orderkey1

         CREATE TABLE #t_orderkey1 (OrderKey NVARCHAR( 10))

         INSERT INTO #t_orderkey1 (OrderKey)
         SELECT T.OrderKey   
         FROM #t_orderkey T
         JOIN dbo.Pickdetail PD WITH (NOLOCK) ON T.OrderKey = PD.OrderKey
         JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
         GROUP BY T.OrderKey
         -- Only select orders that can be fulfilled by 1 trolley zone only
         HAVING COUNT( DISTINCT T.TZone) = 1


         SELECT TOP 1 @cOrderKey = T1.OrderKey
         FROM #t_orderkey1 T1
         JOIN PICKDETAIL PD (NOLOCK) ON T1.ORDERKEY = PD.ORDERKEY
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
         JOIN LOC LOC (NOLOCK) ON PD.LOC = LOC.LOC
         JOIN CODELKUP CLK (NOLOCK) ON ( LOC.PICKZONE = CLK.CODE  AND O.StorerKey = CLK.StorerKey)
         WHERE ISNULL( CLK.LONG, '') = @cPickZone
         AND   LISTNAME = 'WCSSTATION'
         AND   O.StorerKey = @cStorerKey
         GROUP BY LOC.LogicalLocation, LOC.LOC, O.Priority, T1.OrderKey 
         ORDER BY LOC.LogicalLocation, LOC.LOC, O.Priority, T1.OrderKey 

          -- If no orderkey found
         IF ISNULL( @cOrderKey, '') = '' 
         BEGIN
            SET @nErrNo = 104101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No ord 2 pick
            GOTO Quit
         END
      END
   END

   Quit:
  
END      

GO