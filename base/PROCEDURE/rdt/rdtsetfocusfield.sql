SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure: rdtSetFocusField                                         */
/* Creation Date:                                                             */
/* Copyright: IDS                                                             */
/* Written by:                                                                */
/*                                                                            */
/* Purpose:                                                                   */
/*                                                                            */
/* Called By:                                                                 */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author        Purposes                                        */
/* 2010-12-04   ChewKP        Changes for RDT2 Column Attribute (ChewKP01)    */
/* 2013-06-27   Ung           Set focus for V_FieldName                       */
/* 2016-09-23   Ung           Performance tuning. Remove RDTVersion           */
/******************************************************************************/

CREATE PROC [RDT].[rdtSetFocusField] (
   @nMobile    int  ,
   @cField     NVARCHAR( 20) 
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF
   
   UPDATE RDT.RDTXML_Root WITH (ROWLOCK) SET 
      Focus = CASE WHEN IsNumeric( @cField) = 1
                   THEN 'I_Field' + RIGHT('0' + RTRIM( @cField), 2)
                   ELSE @cField
              END
   WHERE Mobile = @nMobile


GO