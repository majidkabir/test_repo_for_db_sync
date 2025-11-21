SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/          
/* Store Procedure: isp_SSRS_GetMBOLValidationError                          */          
/* Creation Date:  11/11/2020                                                */          
/* Copyright: LFL                                                            */          
/* Written by: Shong                                                         */          
/*                                                                           */          
/* Purpose: MBOL Validation                                                  */          
/*                                                                           */          
/* Called By: SSRS Report               p                                    */          
/*                                                                           */          
/* PVCS Version:                                                             */     
/*                                                                           */    
/*                                                                           */          
/* Version: 7.1                                                              */          
/*                                                                           */          
/* Data Modifications:                                                       */          
/*                                                                           */          
/* Updates:                                                                  */          
/* Date         Author    Ver.  Purposes                                     */       
/*****************************************************************************/          
CREATE PROC [dbo].[isp_SSRS_GetMBOLValidationError]  (  
   @c_StorerKey  nvarchar(15),  
   @d_StartDate  datetime   
)   
AS   
BEGIN  
  
   DECLARE @t_MBOL TABLE (MBOLKey NVARCHAR(10))  
  
   INSERT INTO @t_MBOL (MBOLKey)   
   SELECT DISTINCT(mh.mbolkey)  
   from dbo.MBOL mh (NOLOCK)      
   JOIN MBOLDETAIL AS md WITH(NOLOCK) ON MH.MBOLKey = MD.MBOLKey   
   JOIN ORDERS AS o WITH(NOLOCK) ON o.OrderKey = md.OrderKey   
   WHERE mh.[Status]='5'     
   AND  validatedFlag = 'E'   
   AND mh.editdate >= @d_StartDate  
   AND O.StorerKey = @c_StorerKey   
   AND EXISTS ( SELECT 1   
                FROM dbo.PALLET P (NOLOCK)   
                WHERE P.PalletKey = mh.ExternMbolKey AND P.Status = '9'  )    
   AND EXISTS ( SELECT 1   
                FROM CONTAINER C WITH (NOLOCK)              
                JOIN dbo.ContainerDetail CD WITH (NOLOCK) ON C.ContainerKey = CD.ContainerKey                                       
                WHERE CD.PalletKey = MH.ExternMbolKey              
                AND C.ContainerType = 'ECOM' AND C.[Status] = '9')      
  
   SELECT TM.MBOLKey, ISNULL(MER.ErrorNo,'0') AS [ErrorNo]  
      , ISNULL(MER.[Type],'') AS [Type]  
      , ISNULL(MER.LineText, 'No Records in MBOLErrorReport!') AS [LineText]   
   FROM @t_MBOL TM   
   LEFT OUTER JOIN [dbo].[MBOLErrorReport] MER (nolock)      
   ON TM.MbolKey = MER.MbolKey   
   ORDER BY MER.MBOLKey, MER.seqno   
  
  
END -- Procedure   

GO