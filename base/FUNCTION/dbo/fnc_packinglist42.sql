SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Function:  fnc_PackingList42                                         */  
/* Creation Date: 04-MAY-2018                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*        : WMS-4868 - CN IKEA                                          */  
/*                                                                      */  
/* Called By:  isp_PackListBySku12                                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 04/09/2018   NJOW01    1.0   WMS-6152 Add orders.notes               */  
/* 14/12/2018   WLCHOOI   1.1   WMS-7277 Combine G6 and G7,             */  
/*                              add more text to G6, Remove G7 (WL01)   */  
/* 10/06/2019   WLCHOOI   1.2   WMS-9371 Add New Fields (WL02)          */  
/* 05/05/2020   CHONGCS   1.3   WMS-12994 Add New Fields (CS01)          */  
/************************************************************************/  
  
CREATE FUNCTION [dbo].fnc_PackingList42 (   
                  @c_orderkey NVARCHAR(20)   
) RETURNS @RetPackList42 TABLE   
         (     Orderkey     NVARCHAR(20)  
            ,  A1           NVARCHAR(4000)   
            ,  A2           NVARCHAR(4000)   
            ,  A3           NVARCHAR(4000)   
            ,  A4           NVARCHAR(4000)   
            ,  A5           NVARCHAR(4000)    
            ,  A6           NVARCHAR(4000)    
            ,  A7           NVARCHAR(4000)    
            ,  A8           NVARCHAR(4000)    
            ,  A9           NVARCHAR(4000)    
            ,  A10          NVARCHAR(4000)    
            ,  A11          NVARCHAR(4000)  
            ,  A12          NVARCHAR(4000)   
            ,  A14          NVARCHAR(4000)  --NJOW01  
            ,  B2           NVARCHAR(4000)     
            ,  C1           NVARCHAR(4000)   
            ,  C2           NVARCHAR(4000)       
            ,  C3           NVARCHAR(4000)  
            ,  C4           NVARCHAR(4000)      
            ,  C5           NVARCHAR(4000)   
            ,  C6           NVARCHAR(4000)    
            ,  C7           NVARCHAR(4000)                     
            ,  E1           NVARCHAR(4000)  
            ,  E2           NVARCHAR(4000)    
            ,  E3           NVARCHAR(4000)    
            ,  E4           NVARCHAR(4000)    
            ,  E5           NVARCHAR(4000)  
            ,  E6           NVARCHAR(4000)   
            ,  E7           NVARCHAR(4000)  
            ,  E8           NVARCHAR(4000)    
            ,  E9           NVARCHAR(4000)    
            ,  G1           NVARCHAR(4000)    
            ,  G2           NVARCHAR(4000)    
            ,  G3           NVARCHAR(4000)    
            ,  G4           NVARCHAR(4000)      
            ,  G5           NVARCHAR(4000)      
            ,  G6           NVARCHAR(4000)    
          --  ,  G7            NVARCHAR(4000)  --WL01  
            ,  G8           NVARCHAR(4000)    
            ,  G9           NVARCHAR(4000)     --WL02  
            ,  G10          NVARCHAR(4000)     --WL02  
            ,  A15          NVARCHAR(4000)  --CS01   
  
         )                                     
AS  
BEGIN  
   SET QUOTED_IDENTIFIER OFF  
  
   DECLARE  @c_LabelName      NVARCHAR(60)  
         ,  @c_LabelValue     NVARCHAR(4000)     
         ,  @c_A1             NVARCHAR(4000)  
         ,  @c_A2             NVARCHAR(4000)  
         ,  @c_A3             NVARCHAR(4000)  
         ,  @c_A4             NVARCHAR(4000)  
         ,  @c_A5             NVARCHAR(4000)  
         ,  @c_A6             NVARCHAR(4000)  
         ,  @c_A7             NVARCHAR(4000)  
         ,  @c_A8             NVARCHAR(4000)  
         ,  @c_A9             NVARCHAR(4000)  
         ,  @c_A10            NVARCHAR(4000)  
         ,  @c_A11            NVARCHAR(4000)  
         ,  @c_A12            NVARCHAR(4000)  
         ,  @c_A14            NVARCHAR(4000) --NJOW01  
         ,  @c_B2             NVARCHAR(4000)  
         ,  @c_C1             NVARCHAR(4000)  
         ,  @c_C2             NVARCHAR(4000)  
         ,  @c_C3             NVARCHAR(4000)  
         ,  @c_C4             NVARCHAR(4000)  
         ,  @c_C5             NVARCHAR(4000)  
         ,  @c_C6             NVARCHAR(4000)  
         ,  @c_C7             NVARCHAR(4000)   
         ,  @c_E1             NVARCHAR(4000)  
         ,  @c_E2             NVARCHAR(4000)  
         ,  @c_E3             NVARCHAR(4000)  
         ,  @c_E4             NVARCHAR(4000)  
         ,  @c_E5             NVARCHAR(4000)  
         ,  @c_E6             NVARCHAR(4000)  
         ,  @c_E7             NVARCHAR(4000)  
         ,  @c_E8             NVARCHAR(4000)  
         ,  @c_E9             NVARCHAR(4000)  
           
         ,  @c_G1             NVARCHAR(4000)  
         ,  @c_G2             NVARCHAR(4000)  
         ,  @c_G3             NVARCHAR(4000)  
         ,  @c_G4             NVARCHAR(4000)  
         ,  @c_G5             NVARCHAR(4000)  
         ,  @c_G6             NVARCHAR(4000)  
        -- ,  @c_G7        NVARCHAR(4000) --WL01  
         ,  @c_G8             NVARCHAR(4000)  
         ,  @c_G9             NVARCHAR(4000)   --WL02  
         ,  @c_G10            NVARCHAR(4000)   --WL02  
         ,  @c_A15            NVARCHAR(4000)   --CS01 
            
  
  
   SET @c_LabelName = ''  
   SET @c_LabelValue= ''  
   SET @c_A1   = ''  
   SET @c_A2   = ''    
   SET @c_A3   = ''    
   SET @c_A4   = ''   
   SET @c_A5   = ''  
   SET @c_A6   = ''  
   SET @c_A7   = ''  
   SET @c_A8   = ''  
   SET @c_A9   = ''  
   SET @c_A10  = ''      
   SET @c_A11  = ''  
   SET @c_A12  = ''      
   SET @c_A14  = ''  --NJOW01      
   SET @c_B2   = ''  
   SET @c_E1   = ''  
   SET @c_E2   = ''      
   SET @c_E3   = ''     
   SET @c_E4   = ''    
   SET @c_E5   = ''     
   SET @c_E6   = ''  
   SET @c_E7   = ''  
   SET @c_E8   = ''   
   SET @c_E9   = ''     
     
   SET @c_G1   = ''     
   SET @c_G2   = ''     
   SET @c_G3   = ''       
   SET @c_G4   = ''     
   SET @c_G5   = ''   
   SET @c_G6   = ''   
  -- SET @c_G7   = '' --WL01  
   SET @c_G8   = ''  
   SET @c_G9   = ''  --WL02     
   SET @c_G10  = ''  --WL02    
   SET @c_C1   = ''   
   SET @c_C2   = ''      
   SET @c_C3   = ''     
   SET @c_C4   = ''   
   SET @c_C5   = ''     
   SET @c_C6   = ''   
   SET @c_C7   = ''     
   SET @c_A15  = ''     --CS01  
    
  
   DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR  
    SELECT CL.code  
         , CL.Notes  
   FROM ORDERS OH WITH (NOLOCK)  
   JOIN CODELKUP    CL WITH (NOLOCK) ON (CL.ListName = 'DOTERRAPAC')   
                                     AND CL.storerkey = OH.storerkey  
     
   WHERE OH.Orderkey = @c_Orderkey       
     
   OPEN CUR_LBL  
  
   FETCH NEXT FROM CUR_LBL INTO @c_LabelName  
                             ,  @c_LabelValue  
                             
        
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN    
      SET @c_A1   =  CASE WHEN @c_LabelName = 'A1'   THEN @c_LabelValue ELSE @c_A1   END   
      SET @c_A2   =  CASE WHEN @c_LabelName = 'A2'   THEN @c_LabelValue ELSE @c_A2   END   
      SET @c_A3   =  CASE WHEN @c_LabelName = 'A3'   THEN @c_LabelValue ELSE @c_A3   END  
      SET @c_A4   =  CASE WHEN @c_LabelName = 'A4'   THEN @c_LabelValue ELSE @c_A4   END   
      SET @c_A5   =  CASE WHEN @c_LabelName = 'A5'   THEN @c_LabelValue ELSE @c_A5   END   
      SET @c_A6   =  CASE WHEN @c_LabelName = 'A6'   THEN @c_LabelValue ELSE @c_A6   END   
      SET @c_A7   =  CASE WHEN @c_LabelName = 'A7'   THEN @c_LabelValue ELSE @c_A7   END   
      SET @c_A8   =  CASE WHEN @c_LabelName = 'A8'   THEN @c_LabelValue ELSE @c_A8   END   
      SET @c_A9   =  CASE WHEN @c_LabelName = 'A9'   THEN @c_LabelValue ELSE @c_A9   END   
      SET @c_A10  =  CASE WHEN @c_LabelName = 'A10'   THEN @c_LabelValue ELSE @c_A10   END   
      SET @c_A11  =  CASE WHEN @c_LabelName = 'A11'   THEN @c_LabelValue ELSE @c_A11   END   
      SET @c_A12  =  CASE WHEN @c_LabelName = 'A12'   THEN @c_LabelValue ELSE @c_A12   END   
      SET @c_A14  =  CASE WHEN @c_LabelName = 'A14'   THEN @c_LabelValue ELSE @c_A14   END  --NJOW01  
      SET @c_B2   =  CASE WHEN @c_LabelName = 'B2'   THEN @c_LabelValue ELSE @c_B2   END   
      SET @c_E1   =  CASE WHEN @c_LabelName = 'E1'   THEN @c_LabelValue ELSE @c_E1   END    
      SET @c_E2   =  CASE WHEN @c_LabelName = 'E2'   THEN @c_LabelValue ELSE @c_E2   END       
      SET @c_E3   =  CASE WHEN @c_LabelName = 'E3'   THEN @c_LabelValue ELSE @c_E3   END     
      SET @c_E4   =  CASE WHEN @c_LabelName = 'E4'   THEN @c_LabelValue ELSE @c_E4   END     
      SET @c_E5   =  CASE WHEN @c_LabelName = 'E5'   THEN @c_LabelValue ELSE @c_E5   END  
      SET @c_E6   =  CASE WHEN @c_LabelName = 'E6'   THEN @c_LabelValue ELSE @c_E6   END      
      SET @c_E7   =  CASE WHEN @c_LabelName = 'E7'   THEN @c_LabelValue ELSE @c_E7   END   
      SET @c_E8   =  CASE WHEN @c_LabelName = 'E8'   THEN @c_LabelValue ELSE @c_E8   END     
      SET @c_E9   =  CASE WHEN @c_LabelName = 'E9'   THEN @c_LabelValue ELSE @c_E9   END     
      SET @c_G1   =  CASE WHEN @c_LabelName = 'G1'   THEN @c_LabelValue ELSE @c_G1   END     
      SET @c_G2   =  CASE WHEN @c_LabelName = 'G2'   THEN @c_LabelValue ELSE @c_G2   END     
      SET @c_G3   =  CASE WHEN @c_LabelName = 'G3'   THEN @c_LabelValue ELSE @c_G3   END       
      SET @c_G4   =  CASE WHEN @c_LabelName = 'G4'   THEN @c_LabelValue ELSE @c_G4   END  
      SET @c_G5   =  CASE WHEN @c_LabelName = 'G5'   THEN @c_LabelValue ELSE @c_G5   END   
      SET @c_G6   =  CASE WHEN @c_LabelName = 'G6'   THEN @c_LabelValue ELSE @c_G6   END  
    --  SET @c_G7   =  CASE WHEN @c_LabelName = 'G7'   THEN @c_LabelValue ELSE @c_G7   END    --WL01  
      SET @c_G8   =  CASE WHEN @c_LabelName = 'G8'   THEN @c_LabelValue ELSE @c_G8   END      
      SET @c_G9   =  CASE WHEN @c_LabelName = 'G9'   THEN @c_LabelValue ELSE @c_G9   END   --WL02     
      SET @c_G10  =  CASE WHEN @c_LabelName = 'G10'  THEN @c_LabelValue ELSE @c_G10  END   --WL02       
      SET @c_C1   =  CASE WHEN @c_LabelName = 'C1'   THEN @c_LabelValue ELSE @c_C1   END   
      SET @c_C2   =  CASE WHEN @c_LabelName = 'C2'   THEN @c_LabelValue ELSE @c_C2   END      
      SET @c_C3   =  CASE WHEN @c_LabelName = 'C3'   THEN @c_LabelValue ELSE @c_C3   END   
      SET @c_C4   =  CASE WHEN @c_LabelName = 'C4'   THEN @c_LabelValue ELSE @c_C4   END     
      SET @c_C5   =  CASE WHEN @c_LabelName = 'C5'   THEN @c_LabelValue ELSE @c_C5   END    
      SET @c_C6   =  CASE WHEN @c_LabelName = 'C6'   THEN @c_LabelValue ELSE @c_C6   END     
      SET @c_C7   =  CASE WHEN @c_LabelName = 'C7'   THEN @c_LabelValue ELSE @c_C7   END    
      SET @c_A15   = CASE WHEN @c_LabelName = 'A15'  THEN @c_LabelValue ELSE @c_A15  END   --CS01   
        
      FETCH NEXT FROM CUR_LBL INTO @c_LabelName  
                                ,  @c_LabelValue  
  
   END  
   CLOSE CUR_LBL  
   DEALLOCATE CUR_LBL  
  
  
  
   INSERT INTO @RetPackList42  
     ( Orderkey    
         ,  A1       
         ,  A2   
         ,  A3  
         ,  A4    
         ,  A5    
         ,  A6    
         ,  A7    
         ,  A8    
         ,  A9    
         ,  A10    
         ,  A11    
         ,  A12     
         ,  A14 --NJOW01  
         ,  B2                                        
         ,  C1  
         ,  C2               
         ,  C3  
         ,  C4               
         ,  C5  
         ,  C6               
         ,  C7              
         ,  E1    
         ,  E2             
         ,  E3   
         ,  E4              
         ,  E5  
         ,  E6  
         ,  E7  
         ,  E8              
         ,  E9    
         ,  G1               
         ,  G2      
         ,  G3              
         ,  G4                        
         ,  G5    
         ,  G6    
       --  ,  G7        --WL01  
         ,  G8  
         ,  G9  --WL02     
         ,  G10 --WL02
         ,  A15 --CS01
         )  
   SELECT @c_orderkey  
         ,  @c_A1   
         ,  @c_A2   
         ,  @c_A3  
         ,  @c_A4   
         ,  @c_A5  
         ,  @c_A6  
         ,  @c_A7  
         ,  @c_A8  
         ,  @c_A9  
         ,  @c_A10  
         ,  @c_A11  
         ,  @c_A12   
         ,  @C_A14 --NJOW01  
         ,  @c_B2  
         ,  @c_C1   
         ,  @c_C2     
         ,  @c_C3  
         ,  @c_C4      
         ,  @c_C5  
         ,  @c_C6      
         ,  @c_C7   
         ,  @c_E1      
         ,  @c_E2  
         ,  @c_E3      
         ,  @c_E4    
         ,  @c_E5  
         ,  @c_E6   
         ,  @c_E7  
         ,  @c_E8     
         ,  @c_E9      
         ,  @c_G1     
         ,  @c_G2     
         ,  @c_G3       
         ,  @c_G4     
         ,  @c_G5     
         ,  @c_G6  
      --   ,  @c_G7  --WL01  
         ,  @c_G8      
         ,  @c_G9  --WL02   
         ,  @c_G10 --WL02  
         ,  @c_A15 --CS01
         
  
   RETURN  
END  

GO