SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* View: V_BuildParmGroupCfg_Columns                                    */  
/* Creation Date: 2022-08-11                                            */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: LFWM-3470 - [CN]NIKE_PHC_Wave Release_Add orderdate filter  */  
/*        :                                                             */  
/* Called By: SCE UI Date Filter Field DropDown                         */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2022-08-11  Wan      1.0   Devops Combine Script                     */  
/************************************************************************/  
CREATE   VIEW dbo.V_BuildParmGroupCfg_Columns AS  
SELECT BuildParmType = 'BuildWaveParm'    
      ,CondType  = 'CONDITION'     
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)          
FROM INFORMATION_SCHEMA.COLUMNS Col         
WHERE Col.TABLE_NAME IN ('ORDERS')                                         
AND Col.COLUMN_NAME IN ('OrderDate', 'DeliveryDate', 'EffectiveDate', 'UserDefine06', 'UserDefine07', 'AddDate', 'EditDate')   
AND Col.Data_Type IN ('datetime')    



GO