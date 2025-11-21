SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function:  fnc_GetDManifestDETTH02                                   */
/* Creation Date: 09-JAN-2020                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-11525 - TH JDSports                                     */
/*                                                                      */
/* Called By:  isp_dmanifest_detail_th02                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_GetDManifestDETTH02] ( 
      @c_mbolkey NVARCHAR(20) 
) RETURNS @RetDManifestDETTH02 TABLE 
         (     mbolkey     NVARCHAR(20)
            ,  A1             NVARCHAR(800) 
            ,  A2             NVARCHAR(800) 
            ,  A10            NVARCHAR(800)    
            ,  B              NVARCHAR(800)  
            ,  D              NVARCHAR(800)  
            ,  F1             NVARCHAR(800)  
            ,  F2             NVARCHAR(800) 
            ,  F3             NVARCHAR(800) 
            ,  F4             NVARCHAR(800)  
            ,  F5             NVARCHAR(800)  
            ,  F6             NVARCHAR(800)  
            ,  G              NVARCHAR(800)  
            ,  I1             NVARCHAR(800)  
            ,  I2             NVARCHAR(800)  
            ,  I3             NVARCHAR(800)  
            ,  J              NVARCHAR(800)  
            ,  K              NVARCHAR(800)  
            ,  L              NVARCHAR(800)   
            ,  M              NVARCHAR(800) 
            ,  N              NVARCHAR(800) 
            ,  P              NVARCHAR(800)
            ,  Q              NVARCHAR(800)   
            ,  CD3            NVARCHAR(800)
            ,  CD4            NVARCHAR(800)
            ,  CD8            NVARCHAR(800)
            ,  CD8_1          NVARCHAR(800)
            ,  CD9            NVARCHAR(800)
            ,  CD9_1          NVARCHAR(800)
            ,  CD10           NVARCHAR(800)
            ,  CD10_1         NVARCHAR(800)
            ,  CD11           NVARCHAR(800)
            ,  CD18           NVARCHAR(800)
            ,  CD19           NVARCHAR(800)
            ,  CD20           NVARCHAR(800)
            ,  CD21           NVARCHAR(800)
            ,  CD22           NVARCHAR(800)
            ,  CD23           NVARCHAR(800)
            ,  CD23_1         NVARCHAR(800)
            ,  CD23_2         NVARCHAR(800)
            ,  CD23_3         NVARCHAR(800)
            ,  CD23_4         NVARCHAR(800)
            ,  CD23_5         NVARCHAR(800)
            ,  CD23_6         NVARCHAR(800)
            ,  CD23_7         NVARCHAR(800)
            ,  CD23_8         NVARCHAR(800)
            ,  CD23_9         NVARCHAR(800)
            ,  CD25           NVARCHAR(800)
            ,  CD26           NVARCHAR(800)         
            ,  CD27           NVARCHAR(800)
            ,  CD28           NVARCHAR(800)
            ,  K2             NVARCHAR(800) 
            ,  C              NVARCHAR(800) 
            ,  CD22_1         NVARCHAR(800)
            )                                   
AS
BEGIN
   SET QUOTED_IDENTIFIER OFF

   DECLARE  @c_LabelName      NVARCHAR(60)
         ,  @c_LabelValue     NVARCHAR(800)   
         ,  @c_A2             NVARCHAR(800)
         ,  @c_A1             NVARCHAR(800)
         ,  @c_A10            NVARCHAR(800)
         ,  @c_B              NVARCHAR(800)
         ,  @c_D              NVARCHAR(800)
         ,  @c_F1             NVARCHAR(800)
         ,  @c_F2             NVARCHAR(800)
         ,  @c_F3             NVARCHAR(800)
         ,  @c_F4             NVARCHAR(800)
         ,  @c_F5             NVARCHAR(800)
         ,  @c_F6             NVARCHAR(800)
         ,  @c_G              NVARCHAR(800)
         ,  @c_I1             NVARCHAR(800)
         ,  @c_I2             NVARCHAR(800)
         ,  @c_I3             NVARCHAR(800)
         ,  @c_J              NVARCHAR(800)
         ,  @c_K              NVARCHAR(800)
         ,  @c_L              NVARCHAR(800)
         ,  @c_M              NVARCHAR(800)
         ,  @c_N              NVARCHAR(800)
         ,  @c_P              NVARCHAR(800)
         ,  @c_NOTES          NVARCHAR(800)
         ,  @c_Q              NVARCHAR(800)      
         ,  @c_CD3            NVARCHAR(800)      
         ,  @c_shipperkey     NVARCHAR(20)       
         ,  @c_CD4            NVARCHAR(800)
         ,  @c_CD8            NVARCHAR(800)
         ,  @c_CD8_1          NVARCHAR(800)
         ,  @c_CD9            NVARCHAR(800)
         ,  @c_CD9_1          NVARCHAR(800)
         ,  @c_CD10           NVARCHAR(800)
         ,  @c_CD10_1         NVARCHAR(800)
         ,  @c_CD11           NVARCHAR(800)
         ,  @c_CD18           NVARCHAR(800)
         ,  @c_CD19           NVARCHAR(800)
         ,  @c_CD20           NVARCHAR(800)
         ,  @c_CD21           NVARCHAR(800)
         ,  @c_CD22           NVARCHAR(800)
         ,  @c_CD23           NVARCHAR(800)
         ,  @c_CD23_1         NVARCHAR(800)
         ,  @c_CD23_2         NVARCHAR(800)
         ,  @c_CD23_3         NVARCHAR(800)
         ,  @c_CD23_4         NVARCHAR(800)
         ,  @c_CD23_5         NVARCHAR(800)
         ,  @c_CD23_6         NVARCHAR(800)
         ,  @c_CD23_7         NVARCHAR(800)
         ,  @c_CD23_8         NVARCHAR(800)
         ,  @c_CD23_9         NVARCHAR(800)
         ,  @c_CD25           NVARCHAR(800)
         ,  @c_CD26           NVARCHAR(800)         
         ,  @c_CD27           NVARCHAR(800)
         ,  @c_CD28           NVARCHAR(800)
         ,  @c_K2             NVARCHAR(800)
         ,  @c_C              NVARCHAR(800)
         ,  @c_CD22_1         NVARCHAR(800)
         


   SET @c_LabelName  = ''
   SET @c_LabelValue = ''
   SET @c_A2         = ''  
   SET @c_A1         = ''  
   SET @c_A10        = '' 
   SET @c_B          = ''   
   SET @c_D          = ''   
   SET @c_F1         = ''  
   SET @c_F2         = '' 
   SET @c_F3         = ''   
   SET @c_F4         = '' 
   SET @c_F5         = ''   
   SET @c_F6         = ''   
   SET @c_G          = ''   
   SET @c_I1         = ''     
   SET @c_I2         = ''   
   SET @c_I3         = '' 
   SET @c_J          = '' 
   SET @c_K          = ''    
   SET @c_L          = ''   
   SET @c_M          = ''   
   SET @c_N          = ''   
   SET @c_P          = ''   
   SET @c_Q          = ''                     
   SET @c_shipperkey = ''               
   SET @c_CD3        = ''                   
   SET @c_CD4        = ''  
   SET @c_CD8        =''   
   SET @c_CD8_1      =''   
   SET @c_CD9        =''   
   SET @c_CD9_1      =''   
   SET @c_CD10       =''   
   SET @c_CD10_1     =''   
   SET @c_CD11       =''   
   SET @c_CD18       =''   
   SET @c_CD19       =''   
   SET @c_CD20       =''   
   SET @c_CD21       =''   
   SET @c_CD22       =''   
   SET @c_CD23       =''   
   SET @c_CD23_1     =''   
   SET @c_CD23_2     =''   
   SET @c_CD23_3     =''   
   SET @c_CD23_4     =''   
   SET @c_CD23_5     =''   
   SET @c_CD23_6     =''   
   SET @c_CD23_7     =''   
   SET @c_CD23_8     =''   
   SET @c_CD23_9     =''   
   SET @c_CD25       =''   
   SET @c_CD26       =''   
   SET @c_CD27       =''   
   SET @c_CD28       =''   
   SET @c_K2         = ''
   SET @c_C          = ''
   SET @c_CD22_1     =''  
                 
  
   DECLARE CUR_LBL CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR
    SELECT CL.code
        , CL.LONG
         , CL.Notes
   FROM CODELKUP    CL WITH (NOLOCK) 
   WHERE (CL.ListName = 'JDRec')     
          
   OPEN CUR_LBL

   FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                             ,  @c_LabelValue
                             ,  @c_NOTES
                           
      
   WHILE @@FETCH_STATUS <> -1
   BEGIN  
      SET @c_A2   =  CASE WHEN @c_LabelName = 'A2'   THEN @c_LabelValue ELSE @c_A2   END 
      SET @c_A1   =  CASE WHEN @c_LabelName = 'A1'   THEN @c_LabelValue ELSE @c_A1   END
      SET @c_A10  =  CASE WHEN @c_LabelName = 'A10'  THEN @c_LabelValue ELSE @c_A10  END  
      SET @c_B    =  CASE WHEN @c_LabelName = 'B'    THEN @c_LabelValue ELSE @c_B    END   
      SET @c_D    =  CASE WHEN @c_LabelName = 'D'    THEN @c_LabelValue ELSE @c_D    END   
      SET @c_F1   =  CASE WHEN @c_LabelName = 'F1'   THEN @c_LabelValue ELSE @c_F1   END  
      SET @c_F2   =  CASE WHEN @c_LabelName = 'F2'   THEN @c_LabelValue ELSE @c_F2   END   
      SET @c_F3   =  CASE WHEN @c_LabelName = 'F3'   THEN @c_LabelValue ELSE @c_F3   END 
      SET @c_F4   =  CASE WHEN @c_LabelName = 'F4'   THEN @c_LabelValue ELSE @c_F4   END 
      SET @c_F5   =  CASE WHEN @c_LabelName = 'F5'   THEN @c_LabelValue ELSE @c_F5   END   
      SET @c_F6   =  CASE WHEN @c_LabelName = 'F6'   THEN @c_LabelValue ELSE @c_F6   END   
      SET @c_G    =  CASE WHEN @c_LabelName = 'G'    THEN @c_LabelValue ELSE @c_F1   END   
      SET @c_I1   =  CASE WHEN @c_LabelName = 'I1'   THEN @c_LabelValue ELSE @c_I1   END     
      SET @c_I2   =  CASE WHEN @c_LabelName = 'I2'   THEN @c_NOTES      ELSE @c_I2   END 
      SET @c_I3   =  CASE WHEN @c_LabelName = 'I3'   THEN @c_LabelValue ELSE @c_I3   END    
      SET @c_J    =  CASE WHEN @c_LabelName = 'J'    THEN @c_LabelValue ELSE @c_J    END   
      SET @c_K    =  CASE WHEN @c_LabelName = 'K'    THEN @c_LabelValue ELSE @c_K    END         
      SET @c_L    =  CASE WHEN @c_LabelName = 'L'    THEN @c_LabelValue ELSE @c_L    END   
      SET @c_M    =  CASE WHEN @c_LabelName = 'M'    THEN @c_LabelValue ELSE @c_M    END   
      SET @c_N    =  CASE WHEN @c_LabelName = 'N'    THEN @c_LabelValue ELSE @c_N    END   
      SET @c_P    =  CASE WHEN @c_LabelName = 'P'    THEN @c_LabelValue ELSE @c_P    END   
      SET @c_Q    =  CASE WHEN @c_LabelName = 'Q'    THEN @c_LabelValue ELSE @c_Q    END          
      SET @c_CD3  =  CASE WHEN @c_LabelName = 'CD3'  THEN @c_LabelValue ELSE @c_CD3  END          
      SET @c_CD4  =  CASE WHEN @c_LabelName = 'CD4'  THEN @c_LabelValue ELSE @c_CD4  END 
      SET @c_CD8  =  CASE WHEN @c_LabelName = 'CD8'  THEN @c_LabelValue ELSE @c_CD8  END          
      SET @c_CD8_1 = CASE WHEN @c_LabelName = 'CD8-1'  THEN @c_NOTES    ELSE @c_CD8_1  END 
      SET @c_CD9  =  CASE WHEN @c_LabelName = 'CD9'    THEN @c_LabelValue ELSE @c_CD9  END          
      SET @c_CD9_1 = CASE WHEN @c_LabelName = 'CD9-1'  THEN @c_NOTES      ELSE @c_CD9_1 END 
      SET @c_CD10  = CASE WHEN @c_LabelName = 'CD10'   THEN @c_LabelValue ELSE @c_CD10  END          
      SET @c_CD10_1= CASE WHEN @c_LabelName = 'CD10-1' THEN @c_NOTES      ELSE @c_CD10_1 END 
      SET @c_CD11  = CASE WHEN @c_LabelName = 'CD11'   THEN @c_LabelValue ELSE @c_CD11  END 
      SET @c_CD18  = CASE WHEN @c_LabelName = 'CD18'   THEN @c_LabelValue ELSE @c_CD18  END  
      SET @c_CD19  = CASE WHEN @c_LabelName = 'CD19'   THEN @c_LabelValue ELSE @c_CD19  END  
      SET @c_CD20  = CASE WHEN @c_LabelName = 'CD20'   THEN @c_LabelValue ELSE @c_CD20  END  
      SET @c_CD21  = CASE WHEN @c_LabelName = 'CD21'   THEN @c_LabelValue ELSE @c_CD21  END  
      SET @c_CD22  = CASE WHEN @c_LabelName = 'CD22'   THEN @c_LabelValue ELSE @c_CD22  END  
      SET @c_CD23  = CASE WHEN @c_LabelName = 'CD23'   THEN @c_LabelValue ELSE @c_CD23  END 
      SET @c_CD23_1 = CASE WHEN @c_LabelName = 'CD23-1'THEN @c_LabelValue ELSE @c_CD23_1  END 
      SET @c_CD23_2 = CASE WHEN @c_LabelName = 'CD23-2'THEN @c_LabelValue ELSE @c_CD23_2  END 
      SET @c_CD23_3 = CASE WHEN @c_LabelName = 'CD23-3'THEN @c_LabelValue ELSE @c_CD23_3  END 
      SET @c_CD23_4 = CASE WHEN @c_LabelName = 'CD23-4'THEN @c_LabelValue ELSE @c_CD23_4  END 
      SET @c_CD23_5 = CASE WHEN @c_LabelName = 'CD23-5'THEN @c_LabelValue ELSE @c_CD23_5  END 
      SET @c_CD23_6 = CASE WHEN @c_LabelName = 'CD23-6'THEN @c_LabelValue ELSE @c_CD23_6  END 
      SET @c_CD23_7 = CASE WHEN @c_LabelName = 'CD23-7'THEN @c_LabelValue ELSE @c_CD23_7  END 
      SET @c_CD23_8 = CASE WHEN @c_LabelName = 'CD23-8'THEN @c_LabelValue ELSE @c_CD23_8  END 
      SET @c_CD23_9 = CASE WHEN @c_LabelName = 'CD23-9'THEN @c_LabelValue ELSE @c_CD23_9  END 
      SET @c_CD25   = CASE WHEN @c_LabelName = 'CD25'  THEN @c_NOTES      ELSE @c_CD25    END 
      SET @c_CD26   = CASE WHEN @c_LabelName = 'CD26'  THEN @c_LabelValue ELSE @c_CD26    END 
      SET @c_CD27   = CASE WHEN @c_LabelName = 'CD27'  THEN @c_LabelValue ELSE @c_CD27    END 
      SET @c_CD28   = CASE WHEN @c_LabelName = 'CD28'  THEN @c_NOTES      ELSE @c_CD28    END 
      SET @c_K2     = CASE WHEN @c_LabelName = 'K2'    THEN @c_LabelValue ELSE @c_K2      END 
      SET @c_C      = CASE WHEN @c_LabelName = 'C'     THEN @c_LabelValue ELSE @c_C    END
      SET @c_CD22_1 = CASE WHEN @c_LabelName = 'CD22-1'  THEN @c_LabelValue ELSE @c_CD22_1  END 
      
      FETCH NEXT FROM CUR_LBL INTO @c_LabelName
                                ,  @c_LabelValue
                                ,  @c_NOTES

   END
   CLOSE CUR_LBL
   DEALLOCATE CUR_LBL



   INSERT INTO @RetDManifestDETTH02
         (  MBOLKEY       
         ,  A1 
         ,  A2
         ,  A10           
         ,  B             
         ,  D 
         ,  F1 
         ,  F2           
         ,  F3
         ,  F4            
         ,  F5  
         ,  F6             
         ,  G            
         ,  I1            
         ,  I2                      
         ,  I3   
         ,  J        
         ,  K                               
         ,  L             
         ,  M             
         ,  N             
         ,  P  
         ,  Q  
         ,  CD3   
         ,  CD4
         ,  CD8
         ,  CD8_1
         ,  CD9
         ,  CD9_1
         ,  CD10
         ,  CD10_1  
         ,  CD11
         ,  CD18
         ,  CD19
         ,  CD20
         ,  CD21 
         ,  CD22
         ,  CD23 
         ,  CD23_1
         ,  CD23_2
         ,  CD23_3
         ,  CD23_4
         ,  CD23_5
         ,  CD23_6
         ,  CD23_7
         ,  CD23_8
         ,  CD23_9   
         ,  CD25
         ,  CD26
         ,  CD27
         ,  CD28  
         ,  K2 
         ,  C 
         ,  CD22_1   
           )
   SELECT @c_mbolkey
         ,  @c_A1 
         ,  @c_A2
         ,  @c_A10
         ,  @c_B    
         ,  @c_D    
         ,  @c_F1
         ,  @c_F2  
         ,  @c_F3 
         ,  @c_F4   
         ,  @c_F5    
         ,  @c_F6     
         ,  @c_G   
         ,  @c_I1     
         ,  @c_I2   
         ,  @c_I3   
         ,  @c_J
         ,  @c_K  
         ,  @c_L    
         ,  @c_M   
         ,  @c_N    
         ,  @c_P          
         ,  @c_Q 
         ,  @c_CD3
         ,  @c_CD4
         ,  @c_CD8
         ,  @c_CD8_1
         ,  @c_CD9
         ,  @c_CD9_1
         ,  @c_CD10
         ,  @c_CD10_1
         ,  @C_CD11
         ,  @c_CD18
         ,  @C_CD19
         ,  @c_CD20
         ,  @C_CD21
         ,  @c_CD22
         ,  @C_CD23
         ,  @C_CD23_1
         ,  @c_CD23_2
         ,  @c_CD23_3
         ,  @C_CD23_4
         ,  @C_CD23_5                        
         ,  @C_CD23_6
         ,  @c_CD23_7
         ,  @c_CD23_8
         ,  @C_CD23_9
         ,  @C_CD25
         ,  @C_CD26
         ,  @C_CD27
         ,  @C_CD28
         ,  @c_K2
         ,  @c_C
         ,  @c_CD22_1

   RETURN
END

GO