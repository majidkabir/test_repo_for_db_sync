SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_GetEPackConfigs]                   */              
/* Creation Date: 10-Oct-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: AlexKeoh                                                 */
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
/* Date           Author   Purposes	                                    */
/* 10-Oct-2024    Alex     #JIRA PAC-355 Initial                        */
/************************************************************************/
CREATE   PROC [API].[isp_ECOMP_GetEPackConfigs](
     @c_StorerKey                      NVARCHAR(15)   = ''
   , @c_Facility                       NVARCHAR(15)   = ''
   , @c_UserId                         NVARCHAR(128)  = ''
   , @c_ComputerName                   NVARCHAR(30)   = ''
   , @c_PackMode                       NVARCHAR(1)    = ''
   , @c_TaskBatchID                    NVARCHAR(10)   = ''
   , @c_OrderKey                       NVARCHAR(10)   = ''
   , @c_DropID                         NVARCHAR(20)   = '' 
   , @c_EPACKConfigJSON                NVARCHAR(4000) = ''  OUTPUT
)
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                 INT            = 1
         , @n_StartCnt                 INT            = @@TRANCOUNT

   DECLARE @c_EPACKCCTV_IsEnabled      NVARCHAR(1)    = ''
         
         , @c_EPACKCCTVRECORDTYPE      NVARCHAR(10)   = ''
         
         , @c_EPACKCCTVOFFSETSEC1      NVARCHAR(1)    = ''
         , @c_EPACKCCTVWMTYPE          NVARCHAR(1)    = ''
         , @c_EPACKCCTVWMLOC           NVARCHAR(1)    = ''
         , @c_EPACKCCTVOFFSETSEC2      NVARCHAR(1)    = ''
         , @c_EPACKCCTVEXSCAN          NVARCHAR(1)    = ''
         , @c_EPACKCCTVWM_CTNNO        NVARCHAR(1)    = ''
         , @c_EPACKCCTVWM_SKU          NVARCHAR(1)    = ''
         , @c_EPACKCCTVWM_SN           NVARCHAR(1)    = ''
         , @c_EPACKCCTVWM_TRACKNO      NVARCHAR(1)    = ''


   DECLARE @t_EPACKConfig  AS Table (
         ConfigName        NVARCHAR(60)      NULL
      ,  [Value]           NVARCHAR(120)     NULL
   )


   --EPACK CCTV Config - Begin
   SET @c_EPACKCCTV_IsEnabled = [API].[fnc_ECOMP_IsCCTVEnabled] ( @c_StorerKey, @c_Facility, @c_ComputerName, @c_UserId ) 

   INSERT INTO @t_EPACKConfig (ConfigName, [Value]) VALUES ('EPACKCCTV_IsEnabled', @c_EPACKCCTV_IsEnabled)

   IF @c_EPACKCCTV_IsEnabled = '1'
   BEGIN
      SET @c_EPACKCCTVWMTYPE     = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKCCTVWMTYPE')
      SET @c_EPACKCCTVWMLOC      = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKCCTVWMLOC')
      SET @c_EPACKCCTVOFFSETSEC1 = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKCCTVOFFSETSEC1')
      SET @c_EPACKCCTVOFFSETSEC2 = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKCCTVOFFSETSEC2')

      SET @c_EPACKCCTVWM_CTNNO = CASE 
                                    WHEN EXISTS ( SELECT 1 FROM [dbo].[Codelkup] WITH (NOLOCK) 
                                                  WHERE ListName = 'CCTVWM' 
                                                  AND Code = 'boxno' 
                                                  AND StorerKey = @c_StorerKey ) THEN '1' 
                                    ELSE '0' 
                                 END

      SET @c_EPACKCCTVWM_SKU = CASE 
                                  WHEN EXISTS ( SELECT 1 FROM [dbo].[Codelkup] WITH (NOLOCK) 
                                                WHERE ListName = 'CCTVWM' 
                                                AND Code = 'skuno' 
                                                AND StorerKey = @c_StorerKey ) THEN '1' 
                                  ELSE '0' 
                               END

      SET @c_EPACKCCTVWM_SN = CASE 
                                 WHEN EXISTS ( SELECT 1 FROM [dbo].[Codelkup] WITH (NOLOCK) 
                                               WHERE ListName = 'CCTVWM' 
                                               AND Code = 'sn' 
                                               AND StorerKey = @c_StorerKey ) THEN '1' 
                                 ELSE '0' 
                              END

      SET @c_EPACKCCTVWM_TRACKNO = CASE 
                                      WHEN EXISTS ( SELECT 1 FROM [dbo].[Codelkup] WITH (NOLOCK) 
                                                    WHERE ListName = 'CCTVWM' 
                                                    AND Code = 'waybillNo' 
                                                    AND StorerKey = @c_StorerKey ) THEN '1' 
                                      ELSE '0' 
                                   END
      
      INSERT INTO @t_EPACKConfig (ConfigName, [Value]) 
      SELECT 'EPACKCCTVWMTYPE'     , @c_EPACKCCTVWMTYPE    
      UNION ALL 
      SELECT 'EPACKCCTVWMLOC'      , @c_EPACKCCTVWMLOC     
      UNION ALL 
      SELECT 'EPACKCCTVOFFSETSEC1' , @c_EPACKCCTVOFFSETSEC1
      UNION ALL 
      SELECT 'EPACKCCTVOFFSETSEC2' , @c_EPACKCCTVOFFSETSEC2
      UNION ALL 
      SELECT 'EPACKCCTVWM_CTNNO'   , @c_EPACKCCTVWM_CTNNO  
      UNION ALL 
      SELECT 'EPACKCCTVWM_SKU'     , @c_EPACKCCTVWM_SKU    
      UNION ALL 
      SELECT 'EPACKCCTVWM_SN'      , @c_EPACKCCTVWM_SN     
      UNION ALL 
      SELECT 'EPACKCCTVWM_TRACKNO' , @c_EPACKCCTVWM_TRACKNO

      IF @c_PackMode = 'M'
      BEGIN
         SET @c_EPACKCCTVRECORDTYPE = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKCCTVRECORDTYPE')

         INSERT INTO @t_EPACKConfig (ConfigName, [Value]) VALUES ('EPACKCCTVRECORDTYPE', IIF(ISNULL(RTRIM(@c_EPACKCCTVRECORDTYPE), '') = '', '0', @c_EPACKCCTVRECORDTYPE))

         SET @c_EPACKCCTVEXSCAN = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'EPACKCCTVEXSCAN')

         INSERT INTO @t_EPACKConfig (ConfigName, [Value]) VALUES ('EPACKCCTVEXSCAN', IIF(ISNULL(RTRIM(@c_EPACKCCTVEXSCAN), '') = '', '0', @c_EPACKCCTVEXSCAN))
      END
   END
   --EPACK CCTV Config - End

   SET @c_EPACKConfigJSON = ISNULL((
                               SELECT 
                                  ConfigName, [Value]
                               FROM @t_EPACKConfig
                               FOR JSON PATH
                             ), '[]')
   QUIT:
   IF @n_Continue= 3  -- Error Occured - Process And Return      
   BEGIN
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1 
      BEGIN               
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END   
      RETURN      
   END      
   ELSE      
   BEGIN   
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN 
         COMMIT TRAN      
      END
      RETURN
   END
END -- Procedure  

GO