SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_750BTSP01                                       */
/* Copyright      : LFL                                                 */
/*                                                                      */
/* Purpose: ANF Ecomm Bartender Printing SP                             */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 05-12-2014  1.0  ChewKP   Created                                    */
/* 24-02-2020  1.1  Leong    INC1049672 - Revise BT Cmd parameters.     */
/************************************************************************/

CREATE PROC [RDT].[rdt_750BTSP01] (
       @nFunc          int,
       @cLangCode      nvarchar(3),
       @cLabelPrinter  nvarchar(10),
       @cDropID        nvarchar(20),
       @cGroupID       nvarchar(20),
       @cAssignMntID   nvarchar(10),
       @cOperatorID    nvarchar(18),
       @nError         int  OUTPUT,
       @cErrMSG        nvarchar(1024) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelType  AS NVARCHAR(30)
          ,@cTaskDetailKey NVARCHAR(10)
          ,@cStorerKey     NVARCHAR(15)

   SELECT @cTaskDetailKey = TaskDetailKey
   FROM dbo.VoiceAssignmentDetail WITH (NOLOCK)
   WHERE AssignmentID = @cAssignMntID

   SELECT @cStorerKey = StorerKey
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey

   SET @nError     = 0
   SET @cErrMSG    = ''

   SET @cLabelType = 'PALLETLABEL01'
   --SELECT @cLabelPrinter '@cLabelPrinter', @cLabelType '@cLabelType' , @cOperatorID '@cOperatorID' , @cDropID '@cDropID' , @cGroupID '@cGroupID' , @cAssignMntID '@cAssignMntID'

   EXEC dbo.isp_BT_GenBartenderCommand
         @cPrinterID     = @cLabelPrinter
       , @c_LabelType    = @cLabelType
       , @c_userid       = @cOperatorID
       , @c_Parm01       = @cDropID
       , @c_Parm02       = @cGroupID
       , @c_Parm03       = @cAssignMntID
       , @c_Parm04       = 0
       , @c_Parm05       = ''
       , @c_Parm06       = ''
       , @c_Parm07       = ''
       , @c_Parm08       = ''
       , @c_Parm09       = ''
       , @c_Parm10       = ''
       , @c_StorerKey    = @cStorerKey
       , @c_NoCopy       = '1'
       , @b_Debug        = '0'
       , @c_Returnresult = 'N'
       , @n_err          = @nError  OUTPUT
       , @c_errmsg       = @cErrMSG OUTPUT

   -- To Proceed Ecomm Despatch while printing having error --
   SET @nError     = 0
   SET @cErrMSG    = ''

END

GO