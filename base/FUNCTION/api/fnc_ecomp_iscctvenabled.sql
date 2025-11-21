SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: [API].[fnc_ECOMP_IsCCTVEnabled]                     */
/* Creation Date: 10-OCT-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: Alex                                                     */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: SCEAPI                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes		                                 */
/* 10-OCT-2024    Alex     #JIRA PAC-356 Initial                        */
/************************************************************************/

CREATE   FUNCTION [API].[fnc_ECOMP_IsCCTVEnabled]
(  
   @c_StorerKey         NVARCHAR(15)   = ''
 , @c_Facility          NVARCHAR(5)    = ''
 , @c_ComputerName      NVARCHAR(30)   = ''
 , @c_UserId            NVARCHAR(128)  = ''
)  
RETURNS NVARCHAR(1) 
AS  
BEGIN     
   DECLARE @c_EPACKCCTV_IsEnabled      NVARCHAR(1)    = '0'

   IF EXISTS ( SELECT 1 FROM [dbo].[Codelkup] WITH (NOLOCK) 
               WHERE ListName = 'CCTVSwitch' AND StorerKey = @c_StorerKey AND UDF01 = @c_Facility AND UDF02 = @c_ComputerName AND [Short] = '1')
   BEGIN
      SET @c_EPACKCCTV_IsEnabled = '1'
      GOTO EXIT_FUNCTION
   END

   SET @c_EPACKCCTV_IsEnabled = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKCCTVTrigger')
   SET @c_EPACKCCTV_IsEnabled = CASE WHEN ISNULL(RTRIM(@c_EPACKCCTV_IsEnabled), '') = '' THEN '0' ELSE ISNULL(RTRIM(@c_EPACKCCTV_IsEnabled), '') END

   EXIT_FUNCTION:
   RETURN @c_EPACKCCTV_IsEnabled
END


GO